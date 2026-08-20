import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';

const _cc = CameraPreset(name: 'K', filmSim: FilmSim.classicChrome, dynamicRange: 400);
const _acros = CameraPreset(name: 'A', filmSim: FilmSim.acros, monoWcX10: 20);

void main() {
  test('the five fields HDR locks come back as one cause, not five bare rows', () {
    // exactly what an X-S20 in HDR rejected: DR, the unidentified D191, both tone curves, clarity
    const skipped = [0xD190, 0xD191, 0xD19D, 0xD19E, 0xD1A2];
    final causes = explainSkips(skipped, preset: _cc, reasons: {for (final c in skipped) c: Resp.invalidDevicePropValue});
    expect(causes, hasLength(1));
    expect(causes.single.headline, contains('HDR'));
    expect(causes.single.fix, contains('HDR'));
    expect(causes.single.codes, skipped);
    expect(causes.single.fields, contains('Clarity'));
  });

  test('D191 alone still explains itself — its bytes came off the slot we just read', () {
    final causes = explainSkips([0xD191], preset: _cc);
    expect(causes.single.headline, contains('D-Range Priority'));
  });

  test('a body that hasn\'t got the property is not told to switch HDR off', () {
    final causes = explainSkips(
      [0xD190, 0xD19D, 0xD1A2],
      preset: _cc,
      reasons: {for (final c in [0xD190, 0xD19D, 0xD1A2]) c: Resp.devicePropNotSupported},
    );
    expect(causes.single.headline, contains("doesn't store"));
    expect(causes.single.codes, [0xD190, 0xD19D, 0xD1A2]);
  });

  test('the tone group without clarity reads as D-Range Priority', () {
    final causes = explainSkips([0xD19D, 0xD19E], preset: _cc);
    expect(causes.single.headline, startsWith('D-Range Priority'));
  });

  test('fields that only exist for some film simulations say so', () {
    expect(explainSkips([0xD193], preset: _cc).single.headline, contains('monochrome'));
    expect(explainSkips([0xD19F], preset: _acros).single.headline, contains('Monochrome'));
    expect(explainSkips([0xD19C], preset: _cc).single.headline, contains('not set to K'));
  });

  test('anything left over is grouped by what the camera answered', () {
    final causes = explainSkips(
      [0xD195, 0xD196, 0xD1A0],
      preset: _cc,
      reasons: {0xD195: Resp.devicePropNotSupported, 0xD196: Resp.devicePropNotSupported, 0xD1A0: Resp.deviceBusy},
    );
    expect(causes, hasLength(2));
    final unsupported = causes.firstWhere((c) => c.codes.contains(0xD195));
    expect(unsupported.codes, [0xD195, 0xD196]);
    expect(unsupported.detail, contains('DevicePropNotSupported'));
    expect(causes.firstWhere((c) => c.codes.contains(0xD1A0)).headline, contains('busy'));
  });

  test('AccessDenied reads as a mode lock, not "no reason given"', () {
    final locked = explainSkips([0xD1A0], preset: _cc, reasons: {0xD1A0: Resp.accessDenied}).single;
    expect(locked.headline, contains('Locked'));
    expect(locked.detail, contains('AccessDenied'));
    expect(locked.fix, contains('HDR'));
  });

  test('every skipped code lands in exactly one cause, whatever the camera said', () {
    final all = [for (var c = 0xD18D; c <= 0xD1A5; c++) c];
    for (final preset in [_cc, _acros]) {
      for (final resp in [
        null,
        Resp.devicePropNotSupported,
        Resp.deviceBusy,
        Resp.invalidDevicePropValue,
        Resp.invalidDevicePropFormat,
        Resp.accessDenied,
        0x2099,
      ]) {
        final causes = explainSkips(all, preset: preset, reasons: resp == null ? const {} : {for (final c in all) c: resp});
        final covered = [for (final c in causes) ...c.codes];
        expect(covered..sort(), all, reason: 'resp=$resp');
        for (final c in causes) {
          expect(c.headline, isNotEmpty);
          expect(c.detail, isNotEmpty);
        }
      }
    }
    expect(explainSkips(const [], preset: _cc), isEmpty);
  });

  test('the camera records why each field was refused', () async {
    final body = FakeFujiBody()..rejectWritesWith[0xD1A2] = Resp.invalidDevicePropValue;
    final c = FujiCamera(PtpTransport(body), slotSettle: Duration.zero);
    await c.openSession();
    await c.discoverCapabilities();
    final r = await c.writePreset(1, _cc);
    expect(r.skipped, [0xD1A2]);
    expect(r.skipReasons, {0xD1A2: Resp.invalidDevicePropValue});
    expect(explainSkips(r.skipped, preset: _cc, reasons: r.skipReasons).single.detail, contains('InvalidDevicePropValue'));
  });
}
