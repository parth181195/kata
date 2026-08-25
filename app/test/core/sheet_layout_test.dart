import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/sheet_layout.dart';

const _rows = [
  SheetRow.gap(0.05),
  SheetRow.band(0.03, id: 'chips'),
  SheetRow.gap(0.06),
  SheetRow.band(0.14, id: 'credits'),
  SheetRow.gap(0.03),
  SheetRow.band(0.20, id: 'title'),
  SheetRow.gap(0.025),
  SheetRow.flex(id: 'photo', minWidths: 0.35),
  SheetRow.gap(0.03),
  SheetRow.band(0.05, id: 'billing'),
  SheetRow.gap(0.045),
];

void main() {
  test('type and margins hold their size across ratios; the picture absorbs the height', () {
    // the same grid on a story, a feed post and a square
    final tall = solveSheet(const Size(600, 1067), _rows); // 9:16
    final feed = solveSheet(const Size(600, 750), _rows); // 4:5
    final square = solveSheet(const Size(600, 600), _rows);

    for (final g in [tall, feed, square]) {
      // sized off the width, so they are identical at every ratio
      expect(g['title'].height, closeTo(600 * 0.20, 0.01));
      expect(g['credits'].height, closeTo(600 * 0.14, 0.01));
      expect(g.margin, closeTo(600 * 0.095, 0.01));
      expect(g['title'].width, closeTo(600 - 2 * 600 * 0.095, 0.01));
    }
    // and the photograph takes what the sheet's shape leaves over
    expect(tall['photo'].height, greaterThan(feed['photo'].height));
    expect(feed['photo'].height, greaterThan(square['photo'].height));
  });

  test('rows stack in order and fill the sheet', () {
    final g = solveSheet(const Size(600, 900), _rows);
    expect(g['chips'].top, lessThan(g['credits'].top));
    expect(g['credits'].bottom, lessThan(g['title'].top));
    expect(g['title'].bottom, lessThan(g['photo'].top));
    expect(g['photo'].bottom, lessThan(g['billing'].top));
    // the last gap is the foot: the billing block doesn't touch the edge
    expect(g['billing'].bottom, closeTo(900 - 600 * 0.045, 0.5));
  });

  test('a short sheet squeezes the air, not the content', () {
    final g = solveSheet(const Size(600, 520), _rows);
    expect(g['title'].height, closeTo(600 * 0.20, 0.01), reason: 'type does not shrink');
    expect(g['photo'].height, closeTo(600 * 0.35, 0.01), reason: 'the picture sits at its floor');
    expect(g['chips'].top, lessThan(600 * 0.05), reason: 'the air above has collapsed');
    expect(g['billing'].bottom, lessThanOrEqualTo(520.5));
  });

  test('a sheet too short even for that takes it out of the picture', () {
    final g = solveSheet(const Size(600, 420), _rows);
    expect(g['title'].height, closeTo(600 * 0.20, 0.01), reason: 'type still does not shrink');
    expect(g['photo'].height, lessThan(600 * 0.35), reason: 'the floor gives way last');
    expect(g['billing'].bottom, lessThanOrEqualTo(420.5), reason: 'everything stays on the sheet');
  });

  test('the picture hangs from the foot of its row, whatever shape it is', () {
    final g = solveSheet(const Size(600, 900), _rows);
    final area = g['photo'];
    final wide = hangInto(area, 3 / 2);
    final tallPhoto = hangInto(area, 2 / 3);
    expect(wide.bottom, closeTo(area.bottom, 0.01));
    expect(tallPhoto.bottom, closeTo(area.bottom, 0.01));
    expect(wide.width, closeTo(area.width, 0.01)); // fills the measure
    expect(tallPhoto.height, lessThanOrEqualTo(area.height + 0.01)); // never overflows
    expect(tallPhoto.center.dx, closeTo(area.center.dx, 0.01));
  });

  test('an unknown row is an empty rect at the foot, not a crash mid-export', () {
    final g = solveSheet(const Size(600, 900), _rows);
    expect(g.has('nope'), isFalse);
    expect(g['nope'].height, 0);
  });
}
