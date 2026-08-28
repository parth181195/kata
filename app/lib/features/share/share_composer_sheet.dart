import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/auth/auth_repository.dart';
import '../../data/recipe.dart';
import '../../core/compose/export.dart';
import 'card_renderer.dart';
import 'place_photo_screen.dart';
import 'photo_import.dart';
import 'photo_meta.dart';
import 'photo_tools.dart';
import 'card_templates.dart';

/// Preview (either page of the pair) · template row S1–S3 · options (invert, embed code, ratio) · photos per frame · `{ }` payload peek · Share.
Future<void> showShareComposer(BuildContext context, Recipe recipe, {List<Uint8List?> photos = const []}) =>
    showKataSheet<void>(context, maxWidth: 980, builder: (_) => ShareComposerSheet(recipe: recipe, initialPhotos: photos));

class ShareComposerSheet extends ConsumerStatefulWidget {
  const ShareComposerSheet({super.key, required this.recipe, this.initialPhotos = const []});
  final Recipe recipe;
  /// Photographs already chosen — the from-a-photo flow arrives with one.
  final List<Uint8List?> initialPhotos;
  @override
  ConsumerState<ShareComposerSheet> createState() => _ShareComposerSheetState();
}

class _ShareComposerSheetState extends ConsumerState<ShareComposerSheet> {
  final _boundary = GlobalKey();
  ShareTemplate _template = ShareTemplate.card;
  /// Which page of the pair the preview shows; the export walks both.
  SharePage _page = SharePage.photo;
  bool _inverted = false;
  bool _outline = false;
  bool _round = true;
  bool _showPayload = false;
  bool _busy = false;
  /// Page 1's photograph (index 0), when the user swaps in their own.
  late final List<Uint8List?> _photos = List.of(widget.initialPhotos);

  /// As chosen, before any rotate/flip/crop — what Reset goes back to.
  late final List<Uint8List?> _originals = List.of(widget.initialPhotos);
  /// Which frame is being rotated/flipped/cropped right now, if any.
  int? _editing;

  /// The photograph's placement in its frame — dragged and pinched on the
  /// preview — and its pixel size, for the clamp. Reset whenever the bytes change.
  Offset _offset = Offset.zero;
  double _zoom = 1;
  Size? _photoSize;
  String? _camera;

  /// The placement page: page 1 large, drag and pinch, Reset and Done.
  Future<void> _place() async {
    final r = await Navigator.of(context).push<(Offset, double)>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlacePhotoScreen(spec: _spec, offset: _offset, zoom: _zoom),
    ));
    if (r == null || !mounted) return;
    setState(() {
      _offset = r.$1;
      _zoom = r.$2;
    });
  }

  Future<void> _measure(Uint8List? b) async {
    if (b == null) {
      setState(() {
        _photoSize = null;
        _camera = null;
      });
      return;
    }
    try {
      final img = await decodeImageFromList(b);
      if (mounted) setState(() => _photoSize = Size(img.width.toDouble(), img.height.toDouble()));
      img.dispose();
    } catch (_) {
      if (mounted) setState(() => _photoSize = null);
    }
    // the camera, read off the photo — a turn or a mirror keeps the EXIF, so
    // this only changes when the photo does
    final meta = await readPhotoMeta(b);
    if (mounted) setState(() => _camera = cameraName(meta));
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotos.isNotEmpty) _measure(widget.initialPhotos.first);
  }

  Uint8List? _photoAt(int i) => i < _photos.length ? _photos[i] : null;
  void _setPhoto(int i, Uint8List? b, {bool original = true}) => setState(() {
        while (_photos.length <= i) {
          _photos.add(null);
          _originals.add(null);
        }
        _photos[i] = b;
        if (original) _originals[i] = b;
        if (i == 0) {
          _offset = Offset.zero;
          _zoom = 1;
          _measure(b);
        }
      });

  /// Bake a turn or a mirror into the photo; the original stays for Undo.
  Future<void> _edit(int i, Future<Uint8List> Function(Uint8List) fn) async {
    final src = _photoAt(i);
    if (src == null || _editing != null) return;
    setState(() => _editing = i);
    try {
      final out = await fn(src);
      if (mounted) _setPhoto(i, out, original: false);
    } catch (_) {
      if (mounted) KataToast.show(context, 'Could not edit the photo');
    } finally {
      if (mounted) setState(() => _editing = null);
    }
  }

  Future<void> _changePhoto(int index, {bool gallery = true}) async {
    final res = gallery
        ? await FilePicker.platform.pickFiles(dialogTitle: 'Choose a photo', type: FileType.image, withData: true)
        : await FilePicker.platform.pickFiles(dialogTitle: 'Choose a photo', type: FileType.custom, allowedExtensions: sharePhotoExtensions, withData: true);
    final raw = res?.files.firstOrNull?.bytes;
    if (raw == null || !mounted) return;
    final usable = await prepareSharePhoto(raw);
    if (!mounted) return;
    if (usable == null) {
      KataToast.show(context, "Couldn't read an image out of that file");
      return;
    }
    _setPhoto(index, usable);
  }

  String get _credit {
    final r = widget.recipe;
    if (r.ofr.sourceAttribution != null && r.ofr.sourceAttribution!.isNotEmpty) return r.ofr.sourceAttribution!;
    final me = ref.read(sessionProvider).valueOrNull?.user;
    return r.source == RecipeSource.published && me != null ? me.displayName : 'Kata';
  }

  ShareSpec get _spec => ShareSpec(recipe: widget.recipe, template: _template, inverted: _inverted, outline: _outline, roundCorners: _round, credit: _credit, photos: _photos, page: _page, photoOffset: _offset, photoZoom: _zoom, photoSize: _photoSize, camera: _camera);

  void _pickTemplate(ShareTemplate t) => setState(() => _template = t);

  /// Render the pages asked for — both by default — one after the other
  /// through the same boundary, and hand them over together: to the share
  /// sheet, or, with [save], straight to a file.
  Future<void> _share([List<SharePage> pages = SharePage.values, bool save = false]) async {
    setState(() => _busy = true);
    final restore = _page;
    final files = <(String, Uint8List)>[];
    try {
      for (final pg in pages) {
        setState(() => _page = pg);
        await WidgetsBinding.instance.endOfFrame;
        files.add((shareFileName(widget.recipe, pg), await CardRenderer(_boundary).toPng(pixelRatio: kCardPixelRatio)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _page = restore;
          _busy = false;
        });
        KataToast.show(context, 'Could not render the card');
      }
      return;
    }
    try {
      if (!mounted) return;
      final subject = '${widget.recipe.name} — Kata';
      if (save) {
        await savePngs(context, files);
      } else if (files.length == 1) {
        await deliverPng(context, files.single.$2, name: files.single.$1, subject: subject, text: _spec.caption);
      } else {
        await deliverPngs(context, files, subject: subject, text: _spec.caption);
      }
    } catch (_) {
      if (mounted) KataToast.show(context, 'Card made, but sharing failed — try Save instead');
    } finally {
      if (mounted) {
        setState(() {
          _page = restore;
          _busy = false;
        });
      }
    }
  }

  /// One photo tool: a round icon, its name small beneath.
  Widget _tool({Key? key, required IconData icon, required String label, VoidCallback? onTap, bool busy = false}) {
    final p = context.kata;
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: [
      KataIconCircle(
        size: 44,
        onPressed: onTap,
        child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 19, color: onTap == null ? p.muted : p.fg),
      ),
      const SizedBox(height: 4),
      Text(label, style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.08)),
    ]);
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _spec.caption));
    if (mounted) KataToast.show(context, 'Kata Code copied');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final spec = _spec;
    final previewW = MediaQuery.sizeOf(context).width - 40;
    final scale = (previewW / kCardWidth).clamp(0.3, 1.0);
    // keep the preview from eating the whole sheet; a pair is about 4:5 tall
    final maxH = MediaQuery.sizeOf(context).height * 0.42;
    final natural = (kCardWidth / 0.8) * scale;
    final previewScale = natural > maxH ? scale * (maxH / natural) : scale;

    Widget segmented<T>(List<T> values, T current, String Function(T) label, ValueChanged<T> onPick) => Row(children: [
      for (final v in values) ...[
        KataChip(label: label(v), selected: v == current, onTap: () => onPick(v)),
        const SizedBox(width: 7),
      ],
    ]);

    final wide = MediaQuery.sizeOf(context).width >= 820;
    final shown = wide ? scale.clamp(0.3, 1.0) : previewScale;
    final placeable = _page == SharePage.photo && _photoAt(0) != null;
    // the card and its page chips share one column, as wide as the wider of
    // the two, so the chips start at the card's left edge instead of the sheet's
    final preview = Center(
      child: SizedBox(
        width: kCardWidth * shown,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // a shadow, not a border: the card has its own edge, and a hairline
          // around a white card read as two borders
          // tap page 1 to place the photograph on a page of its own — dragging
          // here fought the sheet's own scrolling
          GestureDetector(
            onTap: !placeable ? null : _place,
            child: Container(
              // no rounded clip: the card's corners are square, and rounding
              // the preview cut its outline at the corners
              decoration: BoxDecoration(boxShadow: [BoxShadow(blurRadius: 18, offset: const Offset(0, 6), color: Colors.black.withValues(alpha: 0.18))]),
              clipBehavior: Clip.hardEdge,
              child: OffscreenCardHost(boundaryKey: _boundary, spec: spec, scale: shown),
            ),
          ),
          const SizedBox(height: 10),
          // the pair, one page at a time
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final pg in SharePage.values)
              KataChip(label: '${SharePage.values.indexOf(pg) + 1} · ${pg.label}', selected: pg == _page, onTap: () => setState(() => _page = pg)),
          ]),
          if (placeable) ...[
            const SizedBox(height: 8),
            Text('TAP THE CARD TO MOVE OR ZOOM THE PHOTO', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.08)),
          ],
        ]),
      ),
    );

    return KataSheet(
      eyebrow: 'Share',
      title: widget.recipe.name,
      // on a desktop window the card sits beside its options instead of above them
      leading: wide ? preview : null,
      children: [
        if (!wide) ...[preview, const SizedBox(height: 16)],
        KataSectionHeader('Template'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: segmented<ShareTemplate>(ShareTemplate.values, _template, (t) => '${t.code} ${t.label}', _pickTemplate),
        ),
        const SizedBox(height: 14),
        KataSectionHeader('Card options'),
        const SizedBox(height: 4),
        // named choices rather than a switch: "WHITE | BLACK" needs no interpreting
        KataListRow(
          title: 'Card',
          trailing: KataChoice<bool>(
            values: const [false, true],
            selected: _inverted,
            label: (v) => v ? 'Black' : 'White',
            onChanged: (v) => setState(() => _inverted = v),
          ),
        ),
        KataListRow(
          title: 'Outline',
          trailing: KataChoice<bool>(
            values: const [false, true],
            selected: _outline,
            label: (v) => v ? 'Shown' : 'None',
            onChanged: (v) => setState(() => _outline = v),
          ),
        ),
        KataListRow(
          title: 'Corners',
          trailing: KataChoice<bool>(
            values: const [true, false],
            selected: _round,
            label: (v) => v ? 'Round' : 'Square',
            onChanged: (v) => setState(() => _round = v),
          ),
        ),
        KataListRow(title: 'Credit', value: _credit),
        // page 1's photograph: the recipe's sample, or one of yours — with its
        // own edits as a row of tools
        KataListRow(title: 'Photo', value: _photoAt(0) == null ? 'SAMPLE FRAME' : 'YOURS'),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 10, children: [
          _tool(key: const ValueKey('photo-gallery-0'), icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () => _changePhoto(0)),
          _tool(icon: Icons.folder_open_outlined, label: 'Files', onTap: () => _changePhoto(0, gallery: false)),
          if (_photoAt(0) != null) ...[
            _tool(icon: Icons.rotate_90_degrees_cw_outlined, label: 'Rotate', busy: _editing == 0, onTap: _editing != null ? null : () => _edit(0, rotatePhoto)),
            _tool(icon: Icons.flip_outlined, label: 'Flip', onTap: _editing != null ? null : () => _edit(0, flipPhoto)),
            if (_photoAt(0) != _originals[0])
              _tool(icon: Icons.undo_outlined, label: 'Undo', onTap: () => _setPhoto(0, _originals[0], original: false))
            else
              _tool(icon: Icons.close_outlined, label: 'Remove', onTap: () => _setPhoto(0, null)),
          ],
        ]),
        const SizedBox(height: 6),
        const SizedBox(height: 10),
        Row(children: [
          Text('KATA CODE', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
          const Spacer(),
          KataIconCircle(size: 36, onPressed: () => setState(() => _showPayload = !_showPayload), child: Text('{ }', style: KataType.monoStyle(size: 11, color: p.dim, height: 1))),
        ]),
        if (_showPayload) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.hairline)),
              child: Text(spec.payload, key: const ValueKey('payload'), style: KataType.monoStyle(size: 10.5, color: p.dim, height: 1.6)),
            ),
          ),
          const SizedBox(height: 4),
          Text('${spec.payload.length} BYTES · TAP TO COPY', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.14)),
        ],
        const SizedBox(height: 16),
        // the pair by default — shared, or downloaded — and the previewed page alone beneath
        KataPillButton(label: 'Share both', loading: _busy, onPressed: _busy ? null : () => _share()),
        const SizedBox(height: 8),
        KataPillButton(label: 'Download both', kind: KataButtonKind.secondary, display: false, height: 48, leading: const Icon(Icons.download_outlined, size: 18), onPressed: _busy ? null : () => _share(SharePage.values, true)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: KataPillButton(label: 'Share ${_page.label.toLowerCase()} only', kind: KataButtonKind.secondary, display: false, height: 44, onPressed: _busy ? null : () => _share([_page]))),
          const SizedBox(width: 8),
          Expanded(child: KataPillButton(label: 'Download ${_page.label.toLowerCase()}', kind: KataButtonKind.secondary, display: false, height: 44, onPressed: _busy ? null : () => _share([_page], true))),
        ]),
        const SizedBox(height: 8),
        KataPillButton(label: 'Copy Kata Code', kind: KataButtonKind.secondary, display: false, height: 48, onPressed: _copyCode),
      ],
    );
  }
}

