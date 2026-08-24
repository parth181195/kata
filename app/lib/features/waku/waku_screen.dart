import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'waku_frames.dart';

/// 枠 Waku — put a photo in a good frame. The presets are the point: gallery
/// and museum mats, an instant print, a 35mm strip, a float — picked from live
/// thumbnails. Any image of your own works as a frame too: opaque images
/// become the surround, a PNG with a transparent window sits on top.
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

  Uint8List? _photo;
  Uint8List? _frameImage; // the custom frame, when WakuFrame.custom
  WakuFrame _frame = WakuFrame.gallery;
  WakuRatio _ratio = WakuRatio.r4x5;
  double _matScale = 0.08; // mat unit as a fraction of the short side
  bool _frameOnTop = false; // custom PNGs with a transparent window
  String _caption = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
    if (widget.initialFrame != null) {
      _frameImage = widget.initialFrame;
      _frame = WakuFrame.custom;
    }
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
  bool get _overlayMode => _frame == WakuFrame.custom && _frameImage != null && _frameOnTop;

  Future<Uint8List?> _pickImage(String title) async {
    final res = await FilePicker.platform.pickFiles(dialogTitle: title, type: FileType.image, withData: true);
    return res?.files.firstOrNull?.bytes;
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
    setState(() => _busy = true);
    const name = 'waku.png';
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // scale so the short side lands around 2048px regardless of preview size
      final ratio = (2048 / boundary.size.shortestSide).clamp(1.0, 6.0);
      final img = await boundary.toImage(pixelRatio: ratio);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      img.dispose();
      if (_isDesktop) {
        final path = await FilePicker.platform.saveFile(dialogTitle: 'Save frame', fileName: name, bytes: bytes);
        if (path != null) {
          final f = File(path);
          if (!await f.exists() || (await f.length()) == 0) await f.writeAsBytes(bytes);
          if (mounted) KataToast.show(context, 'Saved $name');
        }
      } else {
        await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'image/png')]);
      }
    } catch (_) {
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
    final img = Image.memory(_photo!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true);
    if (!interactive) return img;
    return ClipRect(
      child: InteractiveViewer(
        transformationController: _viewer,
        minScale: 1,
        maxScale: 6,
        constrained: true,
        child: img,
      ),
    );
  }

  Widget _preview(KataPalette p) {
    if (_photo == null) {
      return KataEmptyState(glyph: '枠', title: 'Waku', body: 'Put a photo in a frame worth the print — or bring your own frame.', actionLabel: 'Choose photo', onAction: _pickPhoto);
    }
    return AspectRatio(
      aspectRatio: _ratio.aspect,
      child: RepaintBoundary(
        key: _boundary,
        child: LayoutBuilder(builder: (context, box) {
          final size = box.biggest;
          final unit = size.shortestSide * _matScale;
          if (_frame == WakuFrame.custom && _frameImage != null) {
            final frameImg = Image.memory(_frameImage!, fit: BoxFit.cover, gaplessPlayback: true);
            return Stack(fit: StackFit.expand, children: [
              if (_overlayMode) ...[
                Positioned.fill(child: _photoWidget()),
                Positioned.fill(child: IgnorePointer(child: frameImg)),
              ] else ...[
                frameImg,
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(unit, unit, unit, _caption.trim().isEmpty ? unit : unit * 2.1),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5))]),
                      child: _photoWidget(),
                    ),
                  ),
                ),
                if (_caption.trim().isNotEmpty)
                  Positioned(
                    left: unit,
                    right: unit,
                    bottom: unit * 0.6,
                    child: Text(_caption.trim().toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: KataType.monoStyle(size: (size.shortestSide * 0.022).clamp(7.0, 15.0), weight: FontWeight.w500, color: Colors.white, letterSpacing: 0.18)
                            .copyWith(shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6)])),
                  ),
              ],
            ]);
          }
          return WakuFramed(frame: _frame, photo: _photoWidget(), size: size, unit: unit, caption: _caption);
        }),
      ),
    );
  }

  /// The frame row shows the frames themselves: live thumbnails, not labels.
  Widget _frameThumb(KataPalette p, WakuFrame f) {
    final on = _frame == f;
    final thumb = f == WakuFrame.custom
        ? (_frameImage == null
            ? Container(
                color: p.surface,
                child: Center(child: Text('+', style: KataType.displayStyle(size: 20, color: p.dim))),
              )
            : Image.memory(_frameImage!, fit: BoxFit.cover, gaplessPlayback: true))
        : WakuFramed(frame: f, photo: _photoWidget(interactive: false), size: const Size(58, 72), unit: 5.6, caption: '');
    return InkWell(
      onTap: () => f == WakuFrame.custom && _frameImage == null ? _pickFrame() : setState(() => _frame = f),
      onDoubleTap: f == WakuFrame.custom ? _pickFrame : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: on ? p.fg : p.hairline, width: on ? 1.5 : 1)),
          child: thumb,
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
          SizedBox(
            height: 96,
            child: ListView.separated(
              key: const ValueKey('waku-frames'),
              scrollDirection: Axis.horizontal,
              itemCount: WakuFrame.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (_, i) => _frameThumb(p, WakuFrame.values[i]),
            ),
          ),
        if (_frame == WakuFrame.custom && _frameImage != null) ...[
          const SizedBox(height: 10),
          KataListRow(title: 'Frame on top', value: _frameOnTop ? 'ON' : 'OFF', onTap: () => setState(() => _frameOnTop = !_frameOnTop)),
          Text('For PNG frames with a transparent window. Off uses the image as the surround behind your photo.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
        ],
        const SizedBox(height: 16),
        KataSectionHeader('Ratio'),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final r in WakuRatio.values) KataChip(label: r.label, selected: _ratio == r, onTap: () => setState(() => _ratio = r)),
        ]),
        if (!_overlayMode) ...[
          const SizedBox(height: 16),
          KataSectionHeader('Mat width'),
          Slider(value: _matScale, min: 0.03, max: 0.16, onChanged: (v) => setState(() => _matScale = v)),
        ],
        const SizedBox(height: 8),
        KataSectionHeader('Caption'),
        KataSearchField(hint: 'Optional caption', onChanged: (v) => setState(() => _caption = v)),
        const SizedBox(height: 20),
        KataPillButton(label: _isDesktop ? 'Save PNG' : 'Share', height: 46, loading: _busy, onPressed: _photo == null ? null : _export),
        const SizedBox(height: 8),
        Text('Drag and pinch the photo to place it in the frame.', textAlign: TextAlign.center, style: KataType.bodyStyle(size: 11, color: p.muted)),
      ];
}
