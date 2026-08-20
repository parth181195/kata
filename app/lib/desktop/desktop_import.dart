import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/fuji/camera_service.dart';
import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import 'desktop_camera.dart';
import 'qr_decode.dart';

/// Everything a dropped file can turn into.
enum ImportKind { kataCode, ofrJson }

class ImportOutcome {
  const ImportOutcome({required this.recipe, required this.kind, this.warnings = const [], this.sourceLabel = ''});
  final OfrRecipe recipe;
  final ImportKind kind;
  final List<String> warnings;
  final String sourceLabel;
}

const _imageExts = {'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'tif', 'tiff'};

/// Parse pasted text: a Kata Code or an OFR JSON document.
ImportOutcome? parseImportText(String text, {String sourceLabel = 'pasted text'}) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (KataCode.looksLike(t)) {
    final res = KataCode.decode(t);
    return ImportOutcome(recipe: res.recipe, kind: ImportKind.kataCode, warnings: res.warnings, sourceLabel: sourceLabel);
  }
  final j = jsonDecode(t) as Map<String, dynamic>;
  final r = OfrRecipe.fromJson(j);
  final warnings = <String>[
    if (r.hash != null && r.hash != OfrHasher.compute(r)) 'stored hash ≠ computed (recomputed on save)',
  ];
  return ImportOutcome(recipe: r, kind: ImportKind.ofrJson, warnings: warnings, sourceLabel: sourceLabel);
}

/// Parse a dropped/picked file: card image (QR), .ofr.json, or a text file holding a code.
ImportOutcome? parseImportFile(String path, Uint8List bytes) {
  final name = path.split(Platform.pathSeparator).last;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (_imageExts.contains(ext)) {
    final payload = decodeQrFromImageBytes(bytes);
    if (payload == null) throw const FormatException('No Kata Code found in that picture');
    if (!KataCode.looksLike(payload)) throw const FormatException('That QR is not a Kata Code');
    final res = KataCode.decode(payload);
    return ImportOutcome(recipe: res.recipe, kind: ImportKind.kataCode, warnings: res.warnings, sourceLabel: name);
  }
  return parseImportText(utf8.decode(bytes), sourceLabel: name);
}

Future<String?> showImportDialog(BuildContext context, {String? initialText, String? filePath, Uint8List? fileBytes}) =>
    showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: c.kata.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.kata.hairline)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: _ImportDialog(initialText: initialText, filePath: filePath, fileBytes: fileBytes),
        ),
      ),
    );

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({this.initialText, this.filePath, this.fileBytes});
  final String? initialText;
  final String? filePath;
  final Uint8List? fileBytes;
  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialText ?? '');
  ImportOutcome? _out;
  List<OfrIssue> _issues = const [];
  String? _error;
  bool _busy = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    if (widget.fileBytes != null && widget.filePath != null) {
      _takeFile(widget.filePath!, widget.fileBytes!);
    } else if ((widget.initialText ?? '').isNotEmpty) {
      _takeText(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply(ImportOutcome? out, String? error) {
    setState(() {
      _out = out;
      _error = error;
      _issues = out == null ? const [] : OfrValidator.validate(out.recipe);
      _busy = false;
    });
  }

  void _takeText(String text) {
    try {
      _apply(parseImportText(text), null);
    } on FormatException catch (e) {
      _apply(null, e.message.startsWith('Not a Kata Code') ? e.message : 'Not valid JSON or a Kata Code');
    } catch (_) {
      _apply(null, 'Not valid JSON or a Kata Code');
    }
  }

  Future<void> _takeFile(String path, Uint8List bytes) async {
    setState(() => _busy = true);
    try {
      final out = parseImportFile(path, bytes);
      if (out != null && out.kind == ImportKind.kataCode) _ctrl.text = KataCode.encode(out.recipe, credit: out.recipe.sourceAttribution);
      _apply(out, null);
    } on FormatException catch (e) {
      _apply(null, e.message);
    } catch (_) {
      _apply(null, "Couldn't read that file");
    }
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final f = res?.files.firstOrNull;
    if (f == null) return;
    final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
    if (bytes == null) return;
    await _takeFile(f.path ?? f.name, bytes);
  }

  Future<Recipe?> _save() async {
    final out = _out;
    if (out == null) return null;
    return ref.read(recipeRepositoryProvider).addImported(out.recipe.copyWith(clearHash: true));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final out = _out;
    final blocking = out == null || OfrValidator.hasErrors(_issues);
    final st = ref.watch(cameraServiceProvider);
    final connected = st is CameraReady;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (d) async {
        setState(() => _hovering = false);
        final f = d.files.firstOrNull;
        if (f == null) return;
        await _takeFile(f.path, await f.readAsBytes());
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('IMPORT A KATA', style: KataType.displayStyle(size: 20, color: p.fg)),
          const SizedBox(height: 6),
          Text('The code is read straight out of the picture — a screenshot from anywhere works.', style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
          const SizedBox(height: 14),
          // drop zone
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _hovering ? p.fg : p.hairline, width: _hovering ? 1.5 : 1),
              color: _hovering ? p.surface : Colors.transparent,
            ),
            child: Column(children: [
              if (_busy)
                KataDotsLoader(dot: 5, color: p.fg)
              else
                Text(_hovering ? 'RELEASE TO READ' : 'DROP A CARD IMAGE OR .OFR.JSON', style: KataType.monoStyle(size: 10, weight: FontWeight.w500, color: _hovering ? p.fg : p.muted, letterSpacing: 0.16)),
              const SizedBox(height: 10),
              KataPillButton(label: 'Choose a file', kind: KataButtonKind.secondary, display: false, height: 36, expand: false, onPressed: _busy ? null : _pick),
            ]),
          ),
          const SizedBox(height: 14),
          Text('OR PASTE THE TEXT', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.18)),
          const SizedBox(height: 8),
          KataTextField(
            label: 'Kata Code or OFR JSON',
            controller: _ctrl,
            hint: 'kata1:CC,DR400,…   or   { "v": 1, … }',
            maxLines: 3,
            mono: true,
            onChanged: _takeText,
            onClear: () {
              _ctrl.clear();
              _apply(null, null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            IssueCard(title: "COULDN'T READ THAT", rows: [IssueRow(_error!, 'drop a card picture, an .ofr.json, or paste a kata1: code')]),
          ],
          if (out != null) ...[
            const SizedBox(height: 16),
            const DottedDivider(),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text(out.recipe.name?.toUpperCase() ?? 'UNTITLED', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 17, color: p.fg))),
              Text('${out.kind == ImportKind.kataCode ? 'KATA CODE' : 'OFR JSON'} · ${out.sourceLabel.toUpperCase()}', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.12)),
            ]),
            const SizedBox(height: 12),
            SpecGrid(RecipeSpecs.items(out.recipe, rulers: false).take(8).toList(), valueSize: 13, rowGap: 14, colGap: 10),
            if (out.warnings.isNotEmpty || _issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              IssueCard(
                title: '${out.warnings.length + _issues.length} NOTE${out.warnings.length + _issues.length == 1 ? '' : 'S'}',
                rows: [
                  for (final w in out.warnings) IssueRow('kata code', w),
                  for (final i in _issues) IssueRow(i.field, i.message),
                ],
              ),
            ],
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: KataPillButton(label: 'Cancel', kind: KataButtonKind.secondary, display: false, height: 46, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: 10),
            if (connected)
              Expanded(
                child: KataPillButton(
                  label: 'Save & queue',
                  kind: KataButtonKind.secondary,
                  display: false,
                  height: 46,
                  onPressed: blocking
                      ? null
                      : () async {
                          final saved = await _save();
                          if (saved == null || !context.mounted) return;
                          // queue into the first empty slot, else C1
                          final cam = ref.read(cameraServiceProvider);
                          var slot = 1;
                          if (cam is CameraReady) {
                            final used = ref.read(writeQueueProvider).keys.toSet();
                            slot = List.generate(cam.caps.slotCount, (i) => i + 1).firstWhere((s) => !used.contains(s), orElse: () => 1);
                          }
                          ref.read(writeQueueProvider.notifier).update((q) => {...q, slot: saved});
                          Navigator.of(context).pop(saved.id);
                          KataToast.show(context, 'Saved · queued for C$slot');
                        },
                ),
              ),
            if (connected) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: KataPillButton(
                label: 'Save to Mine',
                height: 46,
                onPressed: blocking
                    ? null
                    : () async {
                        final saved = await _save();
                        if (saved == null || !context.mounted) return;
                        Navigator.of(context).pop(saved.id);
                        KataToast.show(context, 'Saved to Mine');
                      },
              ),
            ),
          ]),
          if (connected) ...[
            const SizedBox(height: 8),
            Text('Imported katas can be written straight to a slot from here.', style: KataType.bodyStyle(size: 11, color: p.muted)),
          ],
        ]),
      ),
    );
  }
}
