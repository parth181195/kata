import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/compose/export.dart';
import '../../core/compose/layers.dart';
import '../../core/compose/stickers.dart';
import 'waku_frames.dart';
import 'waku_import.dart';

/// 枠 Waku — put a photo in a frame from a curated gallery (one for now: the
/// instant print), or bring any image of your own as the frame. Frames are
/// layer stacks inside; users get exactly the handles each layer offers —
/// pan/pinch the photo, tap a text slot to edit it, drag the draggable ones.
/// Accepts JPEG/PNG/WebP and camera RAW (the embedded preview is used).
class WakuScreen extends StatefulWidget {
  const WakuScreen({super.key, this.initialPhoto, this.initialFrame});
  /// Test seams: the pickers can't run under widget tests.
  final Uint8List? initialPhoto;
  final Uint8List? initialFrame;

  @override
  State<WakuScreen> createState() => _WakuScreenState();
}

enum WakuRatio {
  square('1:1', 1),
  r4x5('4:5', 4 / 5),
  r3x2('3:2', 3 / 2),
  story('9:16', 9 / 16);

  const WakuRatio(this.label, this.aspect);
  final String label;
  final double aspect;
}

class _WakuScreenState extends State<WakuScreen> {
  final _boundary = GlobalKey();
  final _viewer = TransformationController();
  final _slotFocus = FocusNode();
  final Map<String, TextEditingController> _slotText = {};
  final Map<String, Offset> _slotDrag = {}; // fractions of the slot's region
  final Map<String, double> _slotScale = {};
  final Map<String, double> _slotAngle = {};
  final Map<String, Color> _slotInk = {};
  final List<StickerInstance> _stickers = [];
  int _stickerSeq = 0;
  String? _editingSlot;
  String? _selected; // 'photo' or a slot id — chrome + contextual controls
  final _keys = FocusNode(debugLabel: 'waku-keys');
  double _photoAngle = 0; // straighten, degrees (placement freedom, not look)
  bool _photoFlip = false;
  bool _placing = false; // pan/zoom/straighten in progress → thirds grid

  Uint8List? _photo;
  Uint8List? _frameImage; // the custom frame, when WakuFrame.custom
  WakuFrame _frame = WakuFrame.polaroid;
  WakuRatio _ratio = WakuRatio.r4x5;
  double _matScale = 0.08; // custom surround inset, fraction of the short side
  bool _frameOnTop = false; // custom PNGs with a transparent window
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
    if (widget.initialFrame != null) {
      _frameImage = widget.initialFrame;
      _frame = WakuFrame.custom;
    }
    _slotFocus.addListener(() {
      if (!_slotFocus.hasFocus && _editingSlot != null) setState(() => _editingSlot = null);
    });
  }

  @override
  void dispose() {
    _keys.dispose();
    _viewer.dispose();
    _slotFocus.dispose();
    for (final c in _slotText.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
  bool get _overlayMode => _frame == WakuFrame.custom && _frameImage != null && _frameOnTop;

  TextEditingController _ctl(String id) => _slotText.putIfAbsent(id, TextEditingController.new);

  Future<Uint8List?> _pickImage(String title) async {
    final res = await FilePicker.platform.pickFiles(dialogTitle: title, type: FileType.custom, allowedExtensions: wakuImportExtensions, withData: true);
    final raw = res?.files.firstOrNull?.bytes;
    if (raw == null) return null;
    final usable = await prepareWakuImage(raw);
    if (usable == null && mounted) KataToast.show(context, "Couldn't read an image out of that file");
    return usable;
  }

  Future<void> _pickPhoto() async {
    final b = await _pickImage('Choose a photo');
    if (b == null || !mounted) return;
    setState(() {
      _photo = b;
      _viewer.value = Matrix4.identity();
    });
  }

  Future<void> _pickFrame() async {
    final b = await _pickImage('Choose a frame image');
    if (b == null || !mounted) return;
    setState(() {
      _frameImage = b;
      _frame = WakuFrame.custom;
    });
  }

  Future<void> _export() async {
    if (_photo == null || _busy) return;
    _slotFocus.unfocus();
    setState(() {
      _editingSlot = null;
      _selected = null; // chrome must never rasterise
      _busy = true; // ComposeCanvasView hides empty-slot invitations while busy
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
    if (_frame == WakuFrame.custom && _frameImage != null) {
      return customLayers(size, size.shortestSide * _matScale,
          frameImage: Image.memory(_frameImage!, fit: BoxFit.cover, gaplessPlayback: true), overlay: _frameOnTop);
    }
    return polaroidLayers(size, size.shortestSide * 0.08);
  }

  Widget _canvas(Size size, {bool interactive = true}) => ComposeCanvasView(
        canvasSize: size,
        layers: _layers(size),
        photo: _photoWidget(interactive: interactive),
        textOf: (id) => _slotText[id]?.text ?? '',
        dragOf: (id) => _slotDrag[id] ?? Offset.zero,
        editingId: interactive ? _editingSlot : null,
        selectedId: interactive && !_busy ? _selected : null,
        onSelect: !interactive ? null : (id) => setState(() => _selected = id),
        hideInvitations: _busy || !interactive,
        onTapText: !interactive
            ? (_) {}
            : (id) => setState(() {
                  // select first; an empty slot means "I want to type" — edit at once,
                  // a filled one edits on the second tap
                  final empty = (_slotText[id]?.text ?? '').trim().isEmpty;
                  if (_selected == id || empty) _editingSlot = id;
                  _selected = id;
                }),
        onDragText: !interactive
            ? (_, _) {}
            // absolute, already snapped and frame-clamped by the canvas
            : (id, o) => setState(() => _slotDrag[id] = o),
        scaleOf: (id) => _slotScale[id] ?? 1,
        angleOf: (id) => _slotAngle[id] ?? 0,
        inkOf: (id) => _slotInk[id],
        onScaleText: !interactive ? null : (id, v) => setState(() => _slotScale[id] = v),
        onRotateText: !interactive ? null : (id, v) => setState(() => _slotAngle[id] = v),
        stickers: _stickers,
        onStickerChanged: !interactive
            ? null
            : (id, pos, angle) => setState(() {
                  final st = _stickers.firstWhere((s) => s.id == id);
                  st.pos = pos;
                  st.angle = angle;
                }),
        editorBuilder: (id, slot, effective) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: slot.region.width - 24),
          child: IntrinsicWidth(
            child: TextField(
              key: const ValueKey('slot-editor'),
              controller: _ctl(id),
              focusNode: _slotFocus,
              autofocus: true,
              minLines: 1,
              maxLines: slot.maxLines,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(slot.maxChars), _UpperCaseFormatter()],
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: effective,
              cursorColor: effective.color,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, constraints: BoxConstraints(minWidth: 60)),
              onSubmitted: (_) => setState(() => _editingSlot = null),
            ),
          ),
        ),
      );

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_editingSlot != null) {
      if (e.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _editingSlot = null);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // the TextField owns the rest
    }
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
      if (e.logicalKey == LogicalKeyboardKey.enter) {
        setState(() => _editingSlot = sel);
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
          body: 'Put a photo in a frame worth the print — or bring your own frame.\nJPEG · PNG · WebP · camera RAW',
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

  Widget _frameThumb(KataPalette p, WakuFrame f) {
    final on = _frame == f;
    const thumbSize = Size(58, 72);
    final Widget thumb;
    if (f == WakuFrame.custom) {
      thumb = _frameImage == null
          ? Container(color: p.surface, child: Center(child: Text('+', style: KataType.displayStyle(size: 20, color: p.dim))))
          : Image.memory(_frameImage!, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      thumb = ComposeCanvasView(
        canvasSize: thumbSize,
        layers: polaroidLayers(thumbSize, thumbSize.shortestSide * 0.08),
        photo: _photoWidget(interactive: false),
        textOf: (_) => '',
        dragOf: (_) => Offset.zero,
        editingId: null,
        hideInvitations: true,
        onTapText: (_) {},
        onDragText: (_, _) {},
        editorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return InkWell(
      onTap: () => f == WakuFrame.custom && _frameImage == null ? _pickFrame() : setState(() => _frame = f),
      onDoubleTap: f == WakuFrame.custom ? _pickFrame : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: thumbSize.width,
          height: thumbSize.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: on ? p.fg : p.hairline, width: on ? 1.5 : 1)),
          child: IgnorePointer(child: thumb),
        ),
        const SizedBox(height: 5),
        Text(f.label.toUpperCase(), style: KataType.monoStyle(size: 7.5, weight: FontWeight.w500, color: on ? p.fg : p.muted, letterSpacing: 0.12)),
      ]),
    );
  }

  List<Widget> _controls(KataPalette p) => [
        Row(children: [
          Expanded(child: Text('WAKU 枠', style: KataType.displayStyle(size: 18, color: p.fg))),
          KataPillButton(label: _photo == null ? 'Photo' : 'Replace', kind: KataButtonKind.secondary, display: false, expand: false, height: 34, onPressed: _pickPhoto),
        ]),
        const SizedBox(height: 16),
        KataSectionHeader('Frame'),
        if (_photo == null)
          Text('Pick a photo first — the frames preview with it.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4))
        else
          Row(children: [
            for (final f in WakuFrame.values) ...[_frameThumb(p, f), const SizedBox(width: 9)],
          ]),
        if (_frame == WakuFrame.custom && _frameImage != null) ...[
          const SizedBox(height: 10),
          KataListRow(title: 'Frame on top', value: _frameOnTop ? 'ON' : 'OFF', onTap: () => setState(() => _frameOnTop = !_frameOnTop)),
          Text('For PNG frames with a transparent window. Off uses the image as the surround behind your photo.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
        ],
        if (_selected == 'photo' && _photo != null) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Photo'),
          Text('Placement only — the look stayed in the camera.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
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
          Text('Drag to place it. Tap again or press Enter to edit; Delete clears. Corner handle sizes it; the stem above tilts it.',
              style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
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
        KataSectionHeader('Ratio'),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final r in WakuRatio.values) KataChip(label: r.label, selected: _ratio == r, onTap: () => setState(() => _ratio = r)),
        ]),
        if (_frame == WakuFrame.custom && _frameImage != null && !_overlayMode) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Surround width'),
          Slider(value: _matScale, min: 0.03, max: 0.16, onChanged: (v) => setState(() => _matScale = v)),
        ],
        const SizedBox(height: 20),
        KataPillButton(label: _isDesktop ? 'Save PNG' : 'Share', height: 46, loading: _busy, onPressed: _photo == null ? null : _export),
        const SizedBox(height: 8),
        Text('Drag and pinch the photo to place it. Tap the frame’s text to edit; drag it to move it.', textAlign: TextAlign.center, style: KataType.bodyStyle(size: 11, color: p.muted)),
      ];
}


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
