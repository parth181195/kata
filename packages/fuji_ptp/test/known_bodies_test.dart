import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

void main() {
  test('forModel matches device-info strings, longest name wins', () {
    expect(KnownBody.forModel('X-S20')!.slug, 'x-s20');
    expect(KnownBody.forModel('FUJIFILM X-T30 II')!.slug, 'x-t30-ii');
    expect(KnownBody.forModel('X-T30')!.slug, 'x-t30');
    expect(KnownBody.forModel('GFX100 II')!.slug, 'gfx100-ii');
    expect(KnownBody.forModel('X-ZZZ9'), isNull);
    expect(KnownBody.all.map((b) => b.slug).toSet().length, KnownBody.all.length); // slugs unique
    expect(KnownBody.all.where((b) => b.tested).map((b) => b.model), ['X-S20']);
  });
}
