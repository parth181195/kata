import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/compose/layers.dart';
import '../../core/compose/roll.dart';
import 'frames/frame.dart';
import 'waku_exif.dart';
import 'waku_grain_measure.dart';

/// Nine rolls of one object at once, for the judgement the tests can't make:
/// does this read as that thing, do the voices differ audibly, is the wear
/// plausible rather than decorative. Not reachable from the app's navigation —
/// run it from a debug entry point.
class DevRollGrid extends StatefulWidget {
  const DevRollGrid({
    super.key,
    required this.photo,
    required this.meta,
    required this.palette,
    required this.grain,
    required this.object,
  });

  final Uint8List photo;
  final PhotoMeta meta;
  final List<Color> palette;
  final PhotoGrain grain;
  final WakuObject object;

  @override
  State<DevRollGrid> createState() => _DevRollGridState();
}

class _DevRollGridState extends State<DevRollGrid> {
  int _base = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => setState(() => _base += 9),
          label: const Text('shuffle'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 4 / 5,
            children: [
              for (var i = 0; i < 9; i++)
                LayoutBuilder(builder: (context, box) {
                  final size = box.biggest;
                  final roll = Roll.draw(
                    seed: _base + i,
                    allowances: widget.object.allowances,
                    palette: widget.palette,
                    filmSim: widget.meta.filmMode,
                    iso: widget.meta.iso,
                  );
                  return ComposeCanvasView(
                    canvasSize: size,
                    grain: true,
                    layers: widget.object.build(ObjectContext(
                      size: size,
                      meta: widget.meta,
                      grain: widget.grain,
                      palette: widget.palette,
                      roll: roll,
                    )),
                    photo: Image.memory(widget.photo, fit: BoxFit.cover),
                    textOf: (_) => '',
                    dragOf: (_) => Offset.zero,
                    editingId: null,
                    hideInvitations: true,
                    onTapText: (_) {},
                    onDragText: (_, _) {},
                    editorBuilder: (_, _, _) => const SizedBox.shrink(),
                  );
                }),
            ],
          ),
        ),
      );
}
