import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/fuji/camera_service.dart';
import '../data/recipe.dart';
import '../features/library/recipe_card.dart' show recipeImage;
import 'desktop_camera.dart';
import 'slot_backups.dart';
import 'slot_identity.dart';

/// Bottom dock shown on library screens while a camera is connected: every slot is a drop
/// target, queued writes show inline, and "Write n" opens the same review diff as the board.
class SlotDock extends ConsumerWidget {
  const SlotDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(cameraServiceProvider);
    if (st is! CameraReady) return const SizedBox.shrink();
    final p = context.kata;
    final queue = ref.watch(writeQueueProvider);
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline)), color: p.bg),
      child: Row(children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.caps.model.toUpperCase(), style: KataType.displayStyle(size: 13, color: p.fg, letterSpacing: 0)),
          const SizedBox(height: 3),
          Text('DROP A CARD ON A SLOT', style: KataType.monoStyle(size: 8, color: p.muted, letterSpacing: 0.14)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Row(children: [
            for (var i = 1; i <= st.caps.slotCount; i++) ...[
              Expanded(child: _DockSlot(slot: i, model: st.caps.model, preset: i <= st.slots.length ? st.slots[i - 1] : null, queued: queue[i])),
              if (i < st.caps.slotCount) const SizedBox(width: 8),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Eject — close the USB session so the camera can charge',
          onPressed: () => ref.read(cameraServiceProvider.notifier).disconnect(),
          icon: Icon(Icons.eject_outlined, size: 16, color: p.muted),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: 'Slot backups',
          onPressed: () => showSlotBackupsDialog(context, ref),
          icon: Icon(Icons.archive_outlined, size: 16, color: p.muted),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        if (queue.isNotEmpty)
          KataPillButton(
            label: 'Write ${queue.length}',
            height: 40,
            expand: false,
            onPressed: st.busy ? null : () => showWriteReview(context, ref),
          )
        else
          Text('C1–C${st.caps.slotCount}', style: KataType.monoStyle(size: 10, color: p.muted)),
      ]),
    );
  }
}

class _DockSlot extends ConsumerWidget {
  const _DockSlot({required this.slot, required this.model, required this.preset, required this.queued});
  final int slot;
  final String model;
  final CameraPreset? preset;
  final Recipe? queued;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final cur = preset;
    final film = cur == null ? null : (OfrEnums.codeToFilmSim[cur.filmSim] ?? '—');
    final ident = cur == null ? null : identifySlot(ref, model, slot, cur);
    final edited = ident?.edited ?? false;
    final shown = queued ?? (edited ? null : ident?.recipe);
    final thumb = shown == null || shown.imageUrls.isEmpty ? null : recipeImage(shown.imageUrls.first);
    final curName = cur == null ? null : (ident?.recipe?.name ?? (cur.name.isEmpty ? film : cur.name));
    return DragTarget<Recipe>(
      onAcceptWithDetails: (d) => ref.read(writeQueueProvider.notifier).update((q) => {...q, slot: d.data}),
      builder: (context, cand, _) {
        final hover = cand.isNotEmpty;
        final active = hover || queued != null;
        return Tooltip(
          message: queued != null ? '${queued!.name} → C$slot (click to revert)' : (cur == null ? 'Empty · drop to fill' : curName!),
          child: InkWell(
            onTap: queued == null ? null : () => ref.read(writeQueueProvider.notifier).update((q) => {...q}..remove(slot)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? p.fg : p.hairline, width: active ? 1.5 : 1),
                color: hover ? p.surface : Colors.transparent,
              ),
              child: Row(children: [
                if (thumb != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 40, height: 40, child: Image(image: thumb, fit: BoxFit.cover))),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('C$slot', style: KataType.displayStyle(size: 11, color: active ? p.fg : p.dim, letterSpacing: 0)),
                      const Spacer(),
                      if (queued != null)
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: p.fg))
                      else if (edited)
                        Tooltip(message: 'Edited on the camera since Kata wrote ${ident!.origin!.name}', child: Text('✎', style: KataType.monoStyle(size: 9, weight: FontWeight.w600, color: p.fg)))
                      else if (ident?.recipe?.verified == true)
                        Text('✓', style: KataType.monoStyle(size: 9, weight: FontWeight.w600, color: p.dim)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      (queued != null ? queued!.name : (cur == null ? 'EMPTY' : curName!)).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KataType.monoStyle(size: 8.5, weight: queued != null ? FontWeight.w500 : FontWeight.w400, color: queued != null ? p.fg : (cur == null ? p.muted : p.dim)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
