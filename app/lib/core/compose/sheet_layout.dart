import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// A frame's vertical grid, solved for whatever shape the sheet is.
///
/// Frames used to place everything as a fraction of the canvas height, which
/// only works at the one ratio they were drawn at: on a 9:16 story the gaps
/// stretch into deserts, on a square the title lands on the photograph. A
/// printed page doesn't behave that way — its type sizes and margins hold, and
/// the picture and the air around it absorb the difference.
///
/// So every measurement here is in **widths**: a fraction of the sheet's width.
/// Rows are stacked top to bottom, [SheetRow.flex] rows share whatever height
/// is left, and when there isn't enough the gaps give way first.
sealed class SheetRow {
  const SheetRow();

  /// Fixed height, in fractions of the sheet width.
  const factory SheetRow.band(double widths, {String? id}) = SheetBand;

  /// Air. Compresses before anything else does.
  const factory SheetRow.gap(double widths) = SheetGap;

  /// Takes what's left. [minWidths] is the floor it refuses to go below.
  const factory SheetRow.flex({String? id, int weight, double minWidths}) = SheetFlex;
}

class SheetBand extends SheetRow {
  const SheetBand(this.widths, {this.id});
  final double widths;
  final String? id;
}

class SheetGap extends SheetRow {
  const SheetGap(this.widths);
  final double widths;
}

class SheetFlex extends SheetRow {
  const SheetFlex({this.id, this.weight = 1, this.minWidths = 0.1});
  final String? id;
  final int weight;
  final double minWidths;
}

/// The solved grid: a rect per identified row, inset by the sheet's margin.
class SheetGrid {
  const SheetGrid(this._rects, this.size, this.margin);
  final Map<String, Rect> _rects;
  final Size size;

  /// Side margin in logical pixels.
  final double margin;

  /// The row's rect, already inset to the text measure. Unknown ids give an
  /// empty rect at the foot rather than throwing: a frame that asks for a row
  /// it didn't declare should look wrong, not crash mid-export.
  Rect operator [](String id) => _rects[id] ?? Rect.fromLTWH(margin, size.height, size.width - 2 * margin, 0);

  bool has(String id) => _rects.containsKey(id);

  /// Everything between [from]'s top and [to]'s bottom, for layers that span rows.
  Rect span(String from, String to) {
    final a = this[from], b = this[to];
    return Rect.fromLTRB(a.left, a.top, a.right, b.bottom);
  }
}

/// Solves [rows] against [size]. [marginWidths] is the side margin, also in
/// fractions of the width, so a wide sheet doesn't get proportionally thin air
/// down its sides.
SheetGrid solveSheet(Size size, List<SheetRow> rows, {double marginWidths = 0.095}) {
  final w = size.width;
  final margin = w * marginWidths;
  final measure = w - 2 * margin;

  var fixed = 0.0, gaps = 0.0, flexMin = 0.0, flexWeight = 0;
  for (final r in rows) {
    switch (r) {
      case SheetBand(:final widths):
        fixed += widths * w;
      case SheetGap(:final widths):
        gaps += widths * w;
      case SheetFlex(:final minWidths, :final weight):
        flexMin += minWidths * w;
        flexWeight += weight;
    }
  }

  // air gives way first; if that isn't enough the picture gives up its floor
  // too, because a squeezed photograph beats a billing block off the sheet
  var gapScale = 1.0;
  var floorScale = 1.0;
  final slack = size.height - fixed - gaps - flexMin;
  if (slack < 0) {
    gapScale = gaps <= 0 ? 1 : math.max(0, (gaps + slack) / gaps);
    final stillShort = size.height - fixed - gaps * gapScale - flexMin;
    if (stillShort < 0 && flexMin > 0) floorScale = math.max(0, (flexMin + stillShort) / flexMin);
  }
  final leftover = math.max(0.0, size.height - fixed - gaps * gapScale - flexMin * floorScale);

  final out = <String, Rect>{};
  var y = 0.0;
  for (final r in rows) {
    switch (r) {
      case SheetBand(:final widths, :final id):
        final h = widths * w;
        if (id != null) out[id] = Rect.fromLTWH(margin, y, measure, h);
        y += h;
      case SheetGap(:final widths):
        y += widths * w * gapScale;
      case SheetFlex(:final id, :final weight, :final minWidths):
        final h = minWidths * w * floorScale + (flexWeight == 0 ? 0 : leftover * weight / flexWeight);
        if (id != null) out[id] = Rect.fromLTWH(margin, y, measure, h);
        y += h;
    }
  }
  return SheetGrid(out, size, margin);
}

/// Fits a box of [aspect] into [area] and hangs it from the area's foot — a
/// print's picture sits on its bottom margin, so the foot keeps its depth
/// whatever shape the photograph is. Null aspect fills the area.
Rect hangInto(Rect area, double? aspect) {
  if (aspect == null || area.height <= 0) return area;
  var w = area.width;
  var h = w / aspect;
  if (h > area.height) {
    h = area.height;
    w = h * aspect;
  }
  final cx = area.center.dx;
  return Rect.fromLTRB(cx - w / 2, area.bottom - h, cx + w / 2, area.bottom);
}
