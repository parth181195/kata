import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe_repository.dart';
import '../../data/recipe_specs.dart';
import '../ofr_io/import_sheet.dart';

/// Abstracts the camera so widget tests can inject detections.
abstract class CodeScanner {
  Widget build(BuildContext context, void Function(String raw) onDetect);
}

class MobileCodeScanner implements CodeScanner {
  final _ctl = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  @override
  Widget build(BuildContext context, void Function(String raw) onDetect) => MobileScanner(
    controller: _ctl,
    onDetect: (capture) {
      for (final b in capture.barcodes) {
        final v = b.rawValue;
        if (v != null && v.isNotEmpty) onDetect(v);
      }
    },
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error.errorCode == MobileScannerErrorCode.permissionDenied ? 'CAMERA PERMISSION DENIED\nALLOW IT IN SETTINGS, OR PASTE THE CODE' : 'CAMERA UNAVAILABLE\nPASTE THE CODE INSTEAD',
          textAlign: TextAlign.center,
          style: KataType.monoStyle(size: 10, color: KataColors.grey500, letterSpacing: 0.12, height: 1.7),
        ),
      ),
    ),
  );
}

final codeScannerProvider = Provider<CodeScanner>((_) => MobileCodeScanner());

/// Design 3a (right): viewfinder → decoded preview card → Review fields / Save to mine.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  KataCodeResult? _decoded;
  String? _rejected; // last non-Kata payload seen

  void _onDetect(String raw) {
    if (_decoded != null) return;
    if (!KataCode.looksLike(raw)) {
      if (_rejected != raw) setState(() => _rejected = raw);
      return;
    }
    try {
      final res = KataCode.decode(raw);
      HapticFeedback.mediumImpact();
      setState(() {
        _decoded = res;
        _rejected = null;
      });
    } on FormatException {
      setState(() => _rejected = raw);
    }
  }

  Future<void> _save() async {
    final res = _decoded!;
    final r = await ref.read(recipeRepositoryProvider).addImported(res.recipe);
    if (!mounted) return;
    KataToast.show(context, 'Saved to Mine');
    context.pushReplacement('/recipe/${r.id}');
  }

  Future<void> _review() async {
    final res = _decoded!;
    final r = await ref.read(recipeRepositoryProvider).addImported(res.recipe);
    if (!mounted) return;
    context.pushReplacement('/edit/${r.id}');
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(codeScannerProvider);
    final d = _decoded;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (d == null) scanner.build(context, _onDetect) else const ColoredBox(color: Colors.black),
        // viewfinder frame
        if (d == null)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5)),
              ),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                KataIconCircle(size: 40, onPressed: () => context.pop(), child: const Icon(Icons.close, size: 16, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Text('SCAN A KATA CODE', style: KataType.displayStyle(size: 18, color: Colors.white, letterSpacing: 0.02))),
                KataPillButton(
                  label: 'Paste instead',
                  kind: KataButtonKind.secondary,
                  display: false,
                  height: 32,
                  expand: false,
                  onPressed: () async {
                    final clip = await Clipboard.getData('text/plain');
                    if (!context.mounted) return;
                    final id = await showImportSheet(context, initialText: clip?.text);
                    if (id != null && context.mounted) context.pushReplacement('/recipe/$id');
                  },
                ),
              ]),
            ),
            const Spacer(),
            if (d == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Column(children: [
                  Text(
                    _rejected == null ? 'Point at the code on any Kata card — no network needed' : 'That QR isn’t a Kata Code — it reads “${_short(_rejected!)}”',
                    textAlign: TextAlign.center,
                    style: KataType.bodyStyle(size: 12.5, color: _rejected == null ? KataColors.grey300 : Colors.white, height: 1.5),
                  ),
                ]),
              )
            else
              _Preview(res: d, onReview: _review, onSave: _save, onRetry: () => setState(() => _decoded = null)),
          ]),
        ),
      ]),
    );
  }

  static String _short(String s) => s.length > 40 ? '${s.substring(0, 40)}…' : s;
}

class _Preview extends StatelessWidget {
  const _Preview({required this.res, required this.onReview, required this.onSave, required this.onRetry});
  final KataCodeResult res;
  final VoidCallback onReview, onSave, onRetry;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final r = res.recipe;
    final sw = RecipeSpecs.swatch(r);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: KataCard(
        key: const ValueKey('scan-preview'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((r.name ?? 'Untitled kata').toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 20, color: p.fg, letterSpacing: 0)),
                const SizedBox(height: 5),
                Text(RecipeSpecs.summary(r).toUpperCase(), style: KataType.monoStyle(size: 10.5, color: p.dim)),
                const SizedBox(height: 6),
                Text('from ${res.credit ?? 'unknown'} · ${res.settingsCount} settings decoded', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 12),
            SwatchBars(heights: sw.heights, greys: sw.greys, abbr: RecipeSpecs.filmAbbr(r)),
          ]),
          const SizedBox(height: 12),
          const DottedDivider(),
          const SizedBox(height: 10),
          Text('Read straight from the image — the code carries the recipe, not a link.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.45)),
          if (res.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(res.warnings.join(' · '), style: KataType.monoStyle(size: 9.5, color: p.red, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: KataPillButton(label: 'Review fields', kind: KataButtonKind.secondary, display: false, height: 48, onPressed: onReview)),
            const SizedBox(width: 10),
            Expanded(child: KataPillButton(label: 'Save to mine', height: 48, onPressed: onSave)),
          ]),
          const SizedBox(height: 8),
          Center(child: KataPillButton(label: 'Scan another', kind: KataButtonKind.tonal, display: false, height: 34, expand: false, onPressed: onRetry)),
        ]),
      ),
    );
  }
}
