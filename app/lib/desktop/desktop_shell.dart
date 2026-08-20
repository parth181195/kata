import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/auth/auth_repository.dart';
import '../core/fuji/camera_service.dart';
import '../data/recipe_repository.dart';
import 'desktop_camera.dart';
import 'desktop_editor.dart';
import 'desktop_import.dart';
import 'desktop_library.dart';
import 'desktop_mine.dart';
import 'desktop_settings.dart';

/// Desktop shell per Kata Desktop.dc.html: 52px top bar (wordmark · context · camera pill · account)
/// + 200px rail (Library / Saved / Mine / Camera / Settings) + content. Mobile keeps its own shell.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  /// Lets any descendant open the editor (detail pane, camera board, dock).
  static DesktopShellController? of(BuildContext context) => context.findAncestorStateOfType<_DesktopShellState>();

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

enum DesktopSection { library, saved, mine, camera, settings, editor }

/// What descendants may ask the shell to do.
abstract class DesktopShellController {
  Future<void> openEditor({String? id, String? from});

  /// Open a brand-new kata seeded with settings (e.g. read out of a camera slot).
  Future<void> openEditorWith(OfrRecipe seed);

  /// The editor reports its unsaved state so every way out of it can ask first.
  void setEditorDirty(bool dirty);
}

class _DesktopShellState extends ConsumerState<DesktopShell> implements DesktopShellController {
  /// A phone gets pull-to-refresh; a desktop window has no such gesture. Arriving at a list
  /// is when you expect it to be current, so that is the trigger — window focus fires far too
  /// often to hang a network call on.
  static const _resyncAfter = Duration(minutes: 2);
  DesktopSection _section = DesktopSection.library;
  DesktopSection _cameFrom = DesktopSection.library;
  late final AppLifecycleListener _lifecycle;
  bool _dropHover = false;

  /// Editor args for the current editing session (null id = new kata).
  ({String? id, String? from})? _editorArgs;
  OfrRecipe? _editorSeed;
  bool _editorDirty = false;

  @override
  void setEditorDirty(bool dirty) => _editorDirty = dirty;

  /// The editor is a section, not a route — leaving it disposes the draft. Every exit
  /// (rail, opening another kata, quitting) goes through here first.
  Future<bool> _mayLeaveEditor() async {
    if (_section != DesktopSection.editor || !_editorDirty) return true;
    final ok = await showKataDialog(context,
        title: 'Discard changes?', body: 'Nothing has been saved yet.', confirmLabel: 'Discard', destructive: true);
    return ok == true;
  }

  @override
  Future<void> openEditor({String? id, String? from}) async {
    if (!await _mayLeaveEditor()) return;
    setState(() {
      _cameFrom = _section == DesktopSection.editor ? _cameFrom : _section;
      _editorArgs = (id: id, from: from);
      _editorSeed = null;
      _editorDirty = false;
      _section = DesktopSection.editor;
    });
  }

  @override
  Future<void> openEditorWith(OfrRecipe seed) async {
    if (!await _mayLeaveEditor()) return;
    setState(() {
      _cameFrom = _section == DesktopSection.editor ? _cameFrom : _section;
      _editorArgs = (id: null, from: null);
      _editorSeed = seed;
      _editorDirty = false;
      _section = DesktopSection.editor;
    });
  }

  Future<void> _goto(DesktopSection s) async {
    if (s == _section) return;
    if (!await _mayLeaveEditor()) return;
    setState(() {
      _editorDirty = false;
      _section = s;
    });
    if (s == DesktopSection.library || s == DesktopSection.saved || s == DesktopSection.mine) _resync();
  }

  @override
  void initState() {
    super.initState();
    // Send CloseSession before we die: otherwise the camera stays latched in USB RAW CONV
    // mode from its side and never falls back to charging until replugged.
    // plug a camera in at any point and Kata picks it up on its own
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cameraServiceProvider.notifier).enableAutoConnect();
    });
    // freshen once at launch; after that, coming back to a list does it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resync();
    });
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
      if (!await _mayLeaveEditor()) return AppExitResponse.cancel;
        await ref.read(cameraServiceProvider.notifier).disconnect();
        return AppExitResponse.exit;
      },
    );
  }

  /// Silent: no spinner, no interruption — the list just becomes current.
  void _resync() {
    final repo = ref.read(recipeRepositoryProvider);
    final last = repo.lastSyncedAt;
    if (repo.syncing) return;
    if (last == null || DateTime.now().difference(last) > _resyncAfter) unawaited(repo.sync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final cam = ref.watch(cameraServiceProvider);
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    final body = switch (_section) {
      DesktopSection.library => const DesktopLibrary(),
      DesktopSection.saved => const DesktopLibrary(savedOnly: true),
      DesktopSection.mine => const DesktopMine(),
      DesktopSection.camera => const DesktopCamera(),
      DesktopSection.settings => const DesktopSettings(),
      DesktopSection.editor => DesktopEditor(
          key: ValueKey((_editorArgs, _editorSeed?.hash ?? _editorSeed?.filmSimulation)),
          id: _editorArgs?.id,
          from: _editorArgs?.from,
          seed: _editorSeed,
          onDirtyChanged: setEditorDirty,
          onDone: () => setState(() {
            _editorDirty = false;
            _section = _cameFrom;
          }),
        ),
    };
    final camPill = switch (cam) {
      CameraReady(:final caps) => KataStatusPill(KataStatus.connected, label: '${caps.model} · C1–C${caps.slotCount}'),
      CameraConnecting() => const KataStatusPill(KataStatus.disconnected, label: 'CONNECTING'),
      _ => const KataStatusPill(KataStatus.noCamera),
    };
    return Scaffold(
      body: DropTarget(
        onDragEntered: (_) {
          if (ModalRoute.of(context)?.isCurrent != true) return;
          setState(() => _dropHover = true);
        },
        onDragExited: (_) => setState(() => _dropHover = false),
        onDragDone: (d) async {
          setState(() => _dropHover = false);
          // A dialog (e.g. the import sheet itself) is on top: let it own the drop.
          if (ModalRoute.of(context)?.isCurrent != true) return;
          final f = d.files.firstOrNull;
          if (f == null) return;
          final nav = Navigator.of(context);
          final bytes = await f.readAsBytes();
          if (!nav.mounted) return;
          await showImportDialog(nav.context, filePath: f.path, fileBytes: bytes);
        },
        child: Stack(children: [
          Column(children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
          child: Row(children: [
            Text('KATA 型', style: KataType.displayStyle(size: 17, weight: FontWeight.w900, color: p.fg, letterSpacing: 0.05)),
            const SizedBox(width: 14),
            Text(_section.name.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
            const Spacer(),
            KataPillButton(
              label: 'Import',
              kind: KataButtonKind.secondary,
              display: false,
              height: 30,
              expand: false,
              onPressed: () => showImportDialog(context),
            ),
            const SizedBox(width: 12),
            camPill,
            const SizedBox(width: 12),
            if (user != null)
              Tooltip(
                message: user.email,
                child: InkWell(
                  onTap: () => _goto(DesktopSection.settings),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(radius: 14, backgroundColor: p.surface, foregroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null, child: Text(user.displayName.isEmpty ? '?' : user.displayName[0], style: KataType.bodyStyle(size: 11, weight: FontWeight.w600, color: p.fg))),
                ),
              ),
          ]),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 200,  // rail
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: p.hairline))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KataPillButton(
                  label: 'New kata',
                  height: 36,
                  onPressed: () => openEditor(),
                ),
                const SizedBox(height: 12),
                for (final (s, label) in [
                  (DesktopSection.library, 'Library'),
                  (DesktopSection.saved, 'Saved'),
                  (DesktopSection.mine, 'Mine'),
                  (DesktopSection.camera, 'Camera'),
                ])
                  _railItem(p, label, s),
                const Spacer(),
                _railItem(p, 'Settings', DesktopSection.settings),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
          ]),
          if (_dropHover)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: p.bg.withValues(alpha: 0.86),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.fg, width: 1.5)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('DROP TO IMPORT', style: KataType.displayStyle(size: 20, color: p.fg)),
                        const SizedBox(height: 6),
                        Text('CARD IMAGE · .OFR.JSON · KATA CODE', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.16)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _railItem(KataPalette p, String label, DesktopSection s) {
    final on = _section == s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? p.fg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _goto(s),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(label, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: on ? p.bg : p.dim, height: 1)),
          ),
        ),
      ),
    );
  }
}
