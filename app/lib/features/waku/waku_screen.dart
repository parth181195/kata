import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';

import '../../core/compose/export.dart';
import '../../core/compose/layers.dart';
import '../../core/compose/roll.dart';
import '../../core/compose/stickers.dart';
import 'frames/frame.dart';
import 'waku_grain_measure.dart';
import 'waku_exif.dart';
import 'waku_import.dart';
import 'waku_palette.dart';

/// 枠 Waku — a photo lands on a printed object: a stamp, a negative strip, a
/// label. You don't choose the object out of a gallery and then wonder what it
/// would look like; something is already composed, and Shuffle re-rolls it.
/// Each axis — object, type, colour, wear — can be kept while the rest move,
/// so you converge on one instead of gambling for it. You can also bring any
/// image of your own as the frame.
///
/// Objects are layer stacks inside; users get exactly the handles each layer
/// offers — pan/pinch the photo, select a text slot and type into the panel,
/// drag the draggable ones. Accepts JPEG/PNG/WebP and camera RAW (the embedded
/// preview is used).
class WakuScreen extends ConsumerStatefulWidget {
  const WakuScreen({super.key, this.initialPhoto, this.initialObject, this.initialMeta});
  /// Test seam: the picker can't run under widget tests.
  final Uint8List? initialPhoto;

  /// Test seam: a generated PNG carries no EXIF, so the prefilled path would
  /// otherwise never run.
  final PhotoMeta? initialMeta;

  /// Test seam: pins the object so a test can target one whose slots grant the
  /// handles it means to exercise.
  final WakuObject? initialObject;

  @override
  ConsumerState<WakuScreen> createState() => WakuScreenState();
}

/// The sheet you're posting to. Objects have no fixed sheet of their own — a
/// stamp is a stamp on a square or on a story — so this is the user's call.
enum WakuRatio {
  square('1:1', 1),
  r4x5('4:5', 4 / 5),
  r3x2('3:2', 3 / 2),
  story('9:16', 9 / 16);

  const WakuRatio(this.label, this.aspect);
  final String label;
  final double aspect;
}

class WakuScreenState extends ConsumerState<WakuScreen> {
  final _boundary = GlobalKey();
  final _viewer = TransformationController();
  final Map<String, TextEditingController> _slotText = {};
  final Map<String, Offset> _slotDrag = {}; // fractions of the slot's region
  final Map<String, double> _slotScale = {};
  final Map<String, double> _slotAngle = {};
  final Map<String, Color> _slotInk = {};
  final List<StickerInstance> _stickers = [];
  int _stickerSeq = 0;
  String? _selected; // 'photo' or a slot id — chrome + contextual controls
  final _keys = FocusNode(debugLabel: 'waku-keys');
  final _slotField = FocusNode(debugLabel: 'waku-slot-field');
  double _photoAngle = 0; // straighten, degrees (placement freedom, not look)
  bool _photoFlip = false;
  bool _placing = false; // pan/zoom/straighten in progress → thirds grid

  Uint8List? _photo;
  PhotoMeta _meta = const PhotoMeta();
  PhotoGrain _grain = PhotoGrain.none;
  List<Color>? _palette;
  /// The recipe riding along: it becomes the object's content, and its Kata
  /// Code becomes the object's code.
  Recipe? _kata;
  String? get kataName => _kata?.name;

  WakuObject _object = kObjects.first;
  Roll _roll = Roll.draw(seed: 1, allowances: kObjects.first.allowances, palette: const []);
  final Set<RollAxis> _pins = {};
  int _seed = 1;
  WakuRatio _ratio = WakuRatio.r4x5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
    if (widget.initialMeta != null) _meta = widget.initialMeta!;
    if (widget.initialObject != null) {
      _object = widget.initialObject!;
      _pins.add(RollAxis.object);
    }
    _roll = Roll.draw(seed: _seed, allowances: _object.allowances, palette: const []);
    // a photo handed straight to the screen never went through the picker, so
    // its matching kata has to be found here instead
    if (_meta.filmMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _kata != null) return;
        final m = _matching(_meta);
        if (m != null) setState(() => _kata = m);
      });
    }
  }

  @override
  void dispose() {
    _keys.dispose();
    _slotField.dispose();
    _viewer.dispose();
    for (final c in _slotText.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  TextEditingController _ctl(String id) => _slotText.putIfAbsent(id, TextEditingController.new);

  /// The current draw. Public because the object it produced is the whole
  /// output — a test that can't read it can only assert on pixels.
  Roll get roll => _roll;

  void _reroll({int? seed}) {
    setState(() {
      _seed = seed ?? _seed + 1;
      if (!_pins.contains(RollAxis.object) && kObjects.length > 1) {
        final next = kObjects[math.Random(_seed * 17).nextInt(kObjects.length)];
        // a slot id belongs to the object that declared it: carrying a
        // selection across would leave the panel editing something that is no
        // longer on the print
        if (next.id != _object.id) _selected = null;
        _object = next;
      }
      _roll = Roll.draw(
        seed: _seed,
        allowances: _object.allowances,
        palette: _palette ?? const [],
        filmSim: _meta.filmMode,
        iso: _meta.iso,
        pinnedFrom: _roll,
        pins: _pins,
      );
    });
  }

  void _togglePin(RollAxis axis) => setState(() => _pins.contains(axis) ? _pins.remove(axis) : _pins.add(axis));

  Future<Uint8List?> _pickImage(String title) async {
    final res = await FilePicker.platform.pickFiles(dialogTitle: title, type: FileType.custom, allowedExtensions: wakuImportExtensions, withData: true);
    final raw = res?.files.firstOrNull?.bytes;
    if (raw == null) return null;
    final usable = await prepareWakuImage(raw);
    if (usable == null && mounted) KataToast.show(context, "Couldn't read an image out of that file");
    return usable;
  }

  /// The kata whose film simulation this shot was taken on, if the library
  /// already has one. A guess, and always replaceable — but the common case is
  /// that you shot the recipe you're about to frame.
  Recipe? _matching(PhotoMeta meta) {
    final sim = meta.filmMode?.toUpperCase();
    if (sim == null) return null;
    return ref.read(recipeRepositoryProvider).all.where((r) => r.ofr.filmSimulation.toUpperCase() == sim).firstOrNull;
  }

  Future<void> _attachKata() async {
    final repo = ref.read(recipeRepositoryProvider);
    final picked = await showKataSheet<Recipe>(
      context,
      builder: (c) => KataSheet(
        eyebrow: 'Waku',
        title: 'Attach a kata',
        children: [
          if (_kata != null) KataListRow(title: 'None', value: 'DETACH', onTap: () => Navigator.of(c).pop(_none)),
          for (final r in repo.all.take(60))
            KataListRow(title: r.name, value: r.ofr.filmSimulation, onTap: () => Navigator.of(c).pop(r)),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _kata = identical(picked, _none) ? null : picked);
  }

  Future<void> _pickPhoto() async {
    final b = await _pickImage('Choose a photo');
    if (b == null || !mounted) return;
    final meta = await readPhotoMeta(b);
    final palette = await extractPalette(b);
    // the sheet's texture is the photo's own grain, so it has to be measured
    final grain = await measurePhotoGrain(b);
    if (!mounted) return;
    setState(() {
      _photo = b;
      _meta = meta;
      _palette = palette;
      _grain = grain;
      _kata = _matching(meta);
      _viewer.value = Matrix4.identity();
    });
    // a new photo is a new shot: it lands on something composed for it, not on
    // whatever the last one happened to roll
    _reroll(seed: DateTime.now().millisecondsSinceEpoch % 100000);
  }

  Future<void> _export() async {
    if (_photo == null || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = null; // chrome must never rasterise
      _busy = true; // hides empty-slot invitations and brings the grain in
    });
    const name = 'waku.png';
    try {
      await WidgetsBinding.instance.endOfFrame; // the busy rebuild (hidden invitations) must paint first
      final png = await rasterizePng(_boundary);
      if (mounted) await deliverPng(context, png, name: name);
    } catch (e, st) {
      debugPrint('waku export failed: $e\n$st');
      if (mounted) KataToast.show(context, 'Could not render the frame');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final controls = _controls(p);
          final preview = Padding(padding: const EdgeInsets.all(20), child: Center(child: _preview(p)));
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: preview),
                  Container(
                    width: 300,
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: p.hairline))),
                    child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 24), children: controls),
                  ),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                  SizedBox(height: box.maxHeight * 0.5, child: preview),
                  ...controls,
                ]);
        }),
      ),
    );
  }

  Widget _photoWidget({bool interactive = true}) {
    var img = Image.memory(_photo!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true) as Widget;
    if (!interactive) return img;
    if (_photoFlip) img = Transform.flip(flipX: true, child: img);
    if (_photoAngle != 0) {
      final a = _photoAngle.abs() * math.pi / 180;
      img = LayoutBuilder(builder: (context, box) {
        // scale so the rotated photo still covers the window's corners
        final w = box.maxWidth, h = box.maxHeight;
        final cover = math.max(math.cos(a) + (h / w) * math.sin(a), math.cos(a) + (w / h) * math.sin(a));
        return Transform.rotate(
          angle: _photoAngle * math.pi / 180,
          child: Transform.scale(scale: cover, child: Image.memory(_photo!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true)),
        );
      });
      if (_photoFlip) img = Transform.flip(flipX: true, child: img);
    }
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        InteractiveViewer(
          transformationController: _viewer,
          minScale: 1,
          maxScale: 6,
          constrained: true,
          onInteractionStart: (_) => setState(() => _placing = true),
          onInteractionEnd: (_) => setState(() => _placing = false),
          child: img,
        ),
        if (_placing && !_busy) const IgnorePointer(child: CustomPaint(painter: _ThirdsPainter())),
      ]),
    );
  }

  List<ComposeLayer> _layers(Size size) {
    return _object.build(ObjectContext(
      size: size,
      meta: _meta,
      grain: _grain,
      palette: _palette ?? const [],
      roll: _roll,
      kataName: _kata?.name,
      kataCode: _kata == null ? null : KataCode.encode(_kata!.ofr),
    ));
  }

  /// Selecting a slot is the edit gesture: the panel's field takes over from
  /// there. A slot the camera filled in seeds the field with what it filled,
  /// so typing starts from the prefill rather than wiping it.
  void _selectSlot(String id) {
    setState(() {
      final prefill = _slotSpec(id)?.prefill?.trim() ?? '';
      if ((_slotText[id]?.text ?? '').trim().isEmpty && prefill.isNotEmpty) _ctl(id).text = prefill;
      _selected = id;
    });
    // on a phone the panel sits below the preview, so the field you just asked
    // for starts off the bottom of the screen. Focusing it scrolls it into
    // view — without that, tapping the text does nothing you can see.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selected == id) _slotField.requestFocus();
    });
  }

  Widget _canvas(Size size, {bool interactive = true}) => ComposeCanvasView(
        canvasSize: size,
        layers: _layers(size),
        photo: _photoWidget(interactive: interactive),
        textOf: (id) => _slotText[id]?.text ?? '',
        dragOf: (id) => _slotDrag[id] ?? Offset.zero,
        selectedId: interactive && !_busy ? _selected : null,
        onSelect: !interactive ? null : (id) => setState(() => _selected = id),
        hideInvitations: _busy || !interactive,
        // the sheet's tooth is a print's texture, not a placement aid: it goes
        // on for the frame we rasterise and stays off while the canvas is live
        grain: _busy,
        onTapText: !interactive ? (_) {} : _selectSlot,
        onDragText: !interactive
            ? (_, _) {}
            // absolute, already snapped and frame-clamped by the canvas
            : (id, o) => setState(() => _slotDrag[id] = o),
        scaleOf: (id) => _slotScale[id] ?? 1,
        angleOf: (id) => _slotAngle[id] ?? 0,
        inkOf: (id) => _slotInk[id],
        stickers: _stickers,
        onStickerChanged: !interactive
            ? null
            : (id, pos, angle) => setState(() {
                  final st = _stickers.firstWhere((s) => s.id == id);
                  st.pos = pos;
                  st.angle = angle;
                }),
      );

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final sel = _selected;
    if (sel == null) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _selected = null);
      return KeyEventResult.handled;
    }
    if (sel.startsWith('sticker:')) {
      final st = _stickers.where((x) => x.id == sel).firstOrNull;
      if (st == null) return KeyEventResult.ignored;
      if (e.logicalKey == LogicalKeyboardKey.delete || e.logicalKey == LogicalKeyboardKey.backspace) {
        _removeSelectedSticker();
        return KeyEventResult.handled;
      }
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final step = shift ? 0.03 : 0.003;
      Offset? d;
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) d = Offset(-step, 0);
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) d = Offset(step, 0);
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) d = Offset(0, -step);
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) d = Offset(0, step);
      if (d != null) {
        setState(() => st.pos = Offset((st.pos.dx + d!.dx).clamp(0.0, 1.0), (st.pos.dy + d.dy).clamp(0.0, 1.0)));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (sel != 'photo') {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final step = shift ? 0.05 : 0.005;
      Offset? d;
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) d = Offset(-step, 0);
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) d = Offset(step, 0);
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) d = Offset(0, -step);
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) d = Offset(0, step);
      if (d != null) {
        setState(() {
          final o = (_slotDrag[sel] ?? Offset.zero) + d!;
          _slotDrag[sel] = Offset(o.dx.clamp(-0.5, 0.5), o.dy.clamp(-0.4, 0.4));
        });
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.delete || e.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() => _slotText[sel]?.clear());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Shelved until the drawings match real references — Parth is capturing
  /// actual tape/pins/seals to draw against. Flip on to bring the kit back.
  static const _stickersEnabled = false;
  static const _stickerAllowance = {StickerType.tape: 2, StickerType.pin: 1, StickerType.hanko: 1};

  int _stickerCount(StickerType t) => _stickers.where((s) => s.type == t).length;

  void _addSticker(StickerType t) {
    if (_stickerCount(t) >= (_stickerAllowance[t] ?? 0)) return;
    setState(() {
      final id = 'sticker:${t.name}-${_stickerSeq++}';
      // arrive slightly off-centre and tilted, like a hand put it there
      final n = _stickers.length;
      _stickers.add(StickerInstance(id: id, type: t, pos: Offset(0.32 + 0.13 * (n % 4), 0.12 + 0.06 * (n % 3)), angle: (n.isEven ? -1 : 1) * 0.12, seed: _stickerSeq * 13 + 5));
      _selected = id;
    });
  }

  void _removeSelectedSticker() => setState(() {
        _stickers.removeWhere((s) => s.id == _selected);
        _selected = null;
      });

  /// The selected slot's spec (capabilities don't depend on canvas size).
  ComposeTextSlot? _slotSpec(String id) {
    for (final l in _layers(const Size(1000, 1250))) {
      if (l is ComposeTextSlot && l.id == id) return l;
    }
    return null;
  }

  void _resetPhoto() => setState(() {
        _viewer.value = Matrix4.identity();
        _photoAngle = 0;
        _photoFlip = false;
      });

  Widget _preview(KataPalette p) {
    if (_photo == null) {
      return KataEmptyState(
          glyph: '枠',
          title: 'Waku',
          body: 'A photo lands on something already made — a stamp, a print, a label.\nJPEG · PNG · WebP · camera RAW',
          actionLabel: 'Choose photo',
          onAction: _pickPhoto);
    }
    return Focus(
      focusNode: _keys,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => _keys.requestFocus(),
        child: AspectRatio(
          aspectRatio: _ratio.aspect,
          child: RepaintBoundary(
            key: _boundary,
            child: LayoutBuilder(builder: (context, box) => _canvas(box.biggest)),
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(KataPalette p) => [
        Row(children: [
          Expanded(child: Text('WAKU 枠', style: KataType.displayStyle(size: 18, color: p.fg))),
          KataPillButton(label: _photo == null ? 'Photo' : 'Replace', kind: KataButtonKind.secondary, display: false, expand: false, height: 34, onPressed: _pickPhoto),
        ]),
        const SizedBox(height: 16),
        if (_photo == null)
          Text('Pick a photo first — it lands on something already composed.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4))
        else ...[
          KataPillButton(
            label: _kata == null ? 'Attach a kata' : _kata!.name,
            kind: KataButtonKind.secondary,
            height: 38,
            onPressed: _attachKata,
          ),
          const SizedBox(height: 6),
          Text(
            _kata == null
                ? 'The recipe becomes the object\u2019s content, and its code rides along.'
                : 'Its code rides on the object, so a scan puts it in someone\u2019s camera.',
            style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          KataPillButton(label: 'Shuffle', height: 46, onPressed: _reroll),
          const SizedBox(height: 12),
          KataSectionHeader('Keep'),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final (axis, label) in const [
              (RollAxis.object, 'Object'),
              (RollAxis.voice, 'Type'),
              (RollAxis.ink, 'Colour'),
              (RollAxis.treatment, 'Wear'),
            ])
              KataChip(
                key: ValueKey('pin-${axis.name}'),
                label: label,
                selected: _pins.contains(axis),
                onTap: () => _togglePin(axis),
              ),
          ]),
          const SizedBox(height: 6),
          Text('Shuffle re-rolls everything you haven\u2019t kept.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
          const SizedBox(height: 16),
          KataSectionHeader('Object'),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final o in kObjects)
              KataChip(
                label: o.label,
                selected: _object.id == o.id,
                onTap: () => setState(() {
                  if (o.id != _object.id) _selected = null;
                  _object = o;
                  _pins.add(RollAxis.object); // choosing one is keeping it
                  _reroll();
                }),
              ),
          ]),
        ],
        if (_selected == 'photo' && _photo != null) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Photo'),
          Text('Placement only — the look stayed in the camera.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
          if (!_meta.isEmpty) ...[
            const SizedBox(height: 8),
            Text(_meta.line, style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.1)),
            if (_meta.filmMode != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_meta.filmMode!.toUpperCase(), style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.1)),
              ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text('STRAIGHTEN', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
            Expanded(
              child: Slider(
                value: _photoAngle,
                min: -7,
                max: 7,
                onChangeStart: (_) => setState(() => _placing = true),
                onChangeEnd: (_) => setState(() => _placing = false),
                onChanged: (v) => setState(() => _photoAngle = v),
              ),
            ),
            Text('${_photoAngle.toStringAsFixed(1)}°', style: KataType.monoStyle(size: 9, color: p.dim)),
          ]),
          Wrap(spacing: 7, children: [
            KataChip(label: 'Flip', selected: _photoFlip, onTap: () => setState(() => _photoFlip = !_photoFlip)),
            KataChip(label: 'Reset', onTap: _resetPhoto),
          ]),
        ],
        if (_selected != null && _selected != 'photo') ...[
          const SizedBox(height: 16),
          KataSectionHeader('Text'),
          const SizedBox(height: 8),
          // the line is typed here, not on the print: an editor sitting on the
          // sheet has to imitate the type it replaces, and never quite does
          KataTextField(
            key: const ValueKey('slot-text'),
            label: 'Line',
            controller: _ctl(_selected!),
            focusNode: _slotField,
            hint: _slotSpec(_selected!)?.invitation,
            maxLines: _slotSpec(_selected!)?.maxLines ?? 1,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_slotSpec(_selected!)?.maxChars ?? 40),
              if (_slotSpec(_selected!)?.uppercase ?? true) _UpperCaseFormatter(),
            ],
            textCapitalization: (_slotSpec(_selected!)?.uppercase ?? true) ? TextCapitalization.characters : TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(() => _slotText[_selected]?.clear()),
          ),
          const SizedBox(height: 8),
          // size and tilt are set here, not by handles on the print: a slider
          // says what it is doing and doesn't fight the drag that places the line
          if (_slotSpec(_selected!)?.scalable ?? false) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('SIZE', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
              Expanded(
                child: Slider(
                  key: const ValueKey('slot-size'),
                  value: (_slotScale[_selected] ?? 1).clamp(_slotSpec(_selected!)!.minScale, _slotSpec(_selected!)!.maxScale),
                  min: _slotSpec(_selected!)!.minScale,
                  max: _slotSpec(_selected!)!.maxScale,
                  onChanged: (v) => setState(() => _slotScale[_selected!] = v),
                ),
              ),
              Text('${((_slotScale[_selected] ?? 1) * 100).round()}%', style: KataType.monoStyle(size: 9, color: p.dim)),
            ]),
          ],
          if (_slotSpec(_selected!)?.rotatable ?? false) ...[
            Row(children: [
              Text('TILT', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
              Expanded(
                child: Slider(
                  key: const ValueKey('slot-tilt'),
                  value: (_slotAngle[_selected] ?? 0).clamp(-_slotSpec(_selected!)!.maxAngle, _slotSpec(_selected!)!.maxAngle),
                  min: -_slotSpec(_selected!)!.maxAngle,
                  max: _slotSpec(_selected!)!.maxAngle,
                  // a hand can't set a pen down at exactly 0.4°, and a line that
                  // means to be level should be level: the middle snaps
                  onChanged: (v) => setState(() => _slotAngle[_selected!] = v.abs() < 0.03 ? 0 : v),
                ),
              ),
              Text('${((_slotAngle[_selected] ?? 0) * 180 / math.pi).toStringAsFixed(1)}°', style: KataType.monoStyle(size: 9, color: p.dim)),
            ]),
          ],
          if ((_slotSpec(_selected!)?.inkChoices ?? const []).isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text('INK', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
              const SizedBox(width: 10),
              for (final ink in _slotSpec(_selected!)!.inkChoices) ...[
                InkWell(
                  key: ValueKey('ink-${ink.toARGB32().toRadixString(16)}'),
                  onTap: () => setState(() => _slotInk[_selected!] = ink),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ink,
                      border: Border.all(color: (_slotInk[_selected] ?? _slotSpec(_selected!)!.style.color) == ink ? p.fg : p.hairline, width: (_slotInk[_selected] ?? _slotSpec(_selected!)!.style.color) == ink ? 2 : 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ],
          const SizedBox(height: 10),
          if (_slotSpec(_selected!)?.draggable ?? false)
            Text('Drag the line on the print to place it.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, children: [
            KataChip(label: 'Clear line', onTap: () => setState(() => _slotText[_selected]?.clear())),
            if ((_slotScale[_selected] ?? 1) != 1 || (_slotAngle[_selected] ?? 0) != 0 || _slotInk[_selected] != null)
              KataChip(
                  label: 'Reset style',
                  onTap: () => setState(() {
                        _slotScale.remove(_selected);
                        _slotAngle.remove(_selected);
                        _slotInk.remove(_selected);
                      })),
          ]),
        ],
        if (_selected != null && _selected!.startsWith('sticker:')) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Sticker'),
          Text('Drag to place it; the stem above tilts it. Delete removes it.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
          const SizedBox(height: 8),
          KataChip(label: 'Remove', onTap: _removeSelectedSticker),
        ],
        if (_stickersEnabled && _photo != null) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Stickers'),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final t in StickerType.values)
              KataChip(
                label: '${t.label} ${_stickerCount(t)}/${_stickerAllowance[t]}',
                enabled: _stickerCount(t) < (_stickerAllowance[t] ?? 0),
                onTap: () => _addSticker(t),
              ),
          ]),
        ],
        const SizedBox(height: 16),
        // an object has no sheet of its own — it sits on whatever you're posting
        // to, and the layout is solved for that ratio
        KataSectionHeader('Ratio'),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final r in WakuRatio.values) KataChip(label: r.label, selected: _ratio == r, onTap: () => setState(() => _ratio = r)),
        ]),
        const SizedBox(height: 20),
        KataPillButton(label: _isDesktop ? 'Save PNG' : 'Share', height: 46, loading: _busy, onPressed: _photo == null ? null : _export),
        const SizedBox(height: 8),
        Text('Drag and pinch the photo to place it. Tap the object’s text to edit it.', textAlign: TextAlign.center, style: KataType.bodyStyle(size: 11, color: p.muted)),
        const SizedBox(height: 6),
        Text('The paper grain goes on when you save.', textAlign: TextAlign.center, style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.1)),
      ];
}


/// Sentinel for "detach", so the sheet can return a deliberate null.
final _none = Recipe(id: '', ofr: const OfrRecipe(filmSimulation: '', dRangePriority: 'Off', grainRoughness: 'Off', whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0));

/// Rule-of-thirds aid shown only while placing the photo; never exported.
class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter();
  @override
  void paint(Canvas c, Size s) {
    final line = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      c.drawLine(Offset(s.width * i / 3, 0), Offset(s.width * i / 3, s.height), line);
      c.drawLine(Offset(0, s.height * i / 3), Offset(s.width, s.height * i / 3), line);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter o) => false;
}


/// The frames set their text in caps — so type in caps, live, rather than
/// jumping to uppercase after focus leaves.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
