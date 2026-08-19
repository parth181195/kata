import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe_repository.dart';
import '../../data/recipe_specs.dart';

/// Paste or pick an OFR JSON, validate, preview, save to Mine.
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({super.key, this.initialText});
  final String? initialText;
  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialText ?? '');
  OfrRecipe? _recipe;
  List<OfrIssue> _issues = const [];
  String? _parseError;

  @override
  void initState() {
    super.initState();
    if ((widget.initialText ?? '').isNotEmpty) _parse(widget.initialText!);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse(String text) {
    setState(() {
      _parseError = null;
      _recipe = null;
      _issues = const [];
      if (text.trim().isEmpty) return;
      try {
        final OfrRecipe r;
        final issues = <OfrIssue>[];
        if (KataCode.looksLike(text)) {
          // a Kata Code pasted from a chat / card
          final res = KataCode.decode(text);
          r = res.recipe;
          issues.addAll(res.warnings.map((w) => OfrIssue('kata code', w, severity: OfrSeverity.warning)));
        } else {
          final j = jsonDecode(text) as Map<String, dynamic>;
          r = OfrRecipe.fromJson(j);
          if (r.hash != null && r.hash != OfrHasher.compute(r)) {
            issues.add(const OfrIssue('hash', 'stored ≠ computed (will be recomputed)', severity: OfrSeverity.warning));
          }
        }
        issues.addAll(OfrValidator.validate(r));
        _recipe = r;
        _issues = issues;
      } on FormatException catch (e) {
        _parseError = e.message.startsWith('Not a Kata Code') ? e.message : 'Not valid JSON or Kata Code';
      } catch (e) {
        _parseError = 'Not valid JSON or Kata Code';
      }
    });
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final f = res?.files.firstOrNull;
    if (f?.bytes == null) return;
    _ctrl.text = utf8.decode(f!.bytes!);
    _parse(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final r = _recipe;
    final blocking = _parseError != null || r == null || OfrValidator.hasErrors(_issues);
    final rows = [
      if (_parseError != null) IssueRow(_parseError!, 'paste the full document or a kata1: code'),
      for (final i in _issues) IssueRow('${i.field}${_fieldValue(r, i.field)}', i.message),
    ];
    return KataSheet(eyebrow: 'Import · paste or pick a file', title: r?.name ?? 'Paste OFR JSON or a Kata Code', children: [
      KataTextField(label: 'OFR JSON or Kata Code', controller: _ctrl, hint: '{ "v": 1, … }  or  kata1:CC,DR400,…', maxLines: 5, mono: true, onChanged: _parse, onClear: () { _ctrl.clear(); _parse(''); }),
      const SizedBox(height: 10),
      Row(children: [
        KataPillButton(label: 'Pick file', kind: KataButtonKind.secondary, display: false, height: 40, expand: false, onPressed: _pickFile),
      ]),
      if (r != null) ...[
        const SizedBox(height: 14),
        const DottedDivider(),
        const SizedBox(height: 14),
        SpecGrid(RecipeSpecs.items(r, rulers: false).take(6).toList(), valueSize: 13, rowGap: 16, colGap: 10),
      ],
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 14),
        IssueCard(title: '${rows.length} FIELD${rows.length == 1 ? '' : 'S'} NEED${rows.length == 1 ? 'S' : ''} ATTENTION', rows: rows),
      ],
      const SizedBox(height: 16),
      Row(children: [
        KataIconCircle(size: 52, onPressed: () { _ctrl.clear(); _parse(''); }, child: Text('↻', style: KataType.bodyStyle(size: 15, color: p.dim, height: 1))),
        const SizedBox(width: 10),
        Expanded(
          child: KataPillButton(
            label: 'Save to Mine',
            height: 52,
            onPressed: blocking
                ? null
                : () async {
                    final lib = ref.read(recipeRepositoryProvider);
                    final saved = await lib.addImported(r.copyWith(clearHash: true));
                    if (!context.mounted) return;
                    Navigator.of(context).pop(saved.id);
                  },
          ),
        ),
      ]),
    ]);
  }

  static String _fieldValue(OfrRecipe? r, String field) {
    if (r == null) return '';
    final v = r.toJson()[field];
    return v == null ? ': missing' : ': $v';
  }
}

Future<String?> showImportSheet(BuildContext context, {String? initialText}) =>
    showKataSheet<String>(context, builder: (_) => ImportSheet(initialText: initialText));
