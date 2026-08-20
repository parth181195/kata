@TestOn('linux')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

/// Live diagnostic against an attached body: every PTP step has its own watchdog so a
/// hang prints WHERE. Skips cleanly when no camera is attached.
void main() {
  test('live: open → session (with stale recovery) → device info → polite close', () async {
    final sw = Stopwatch()..start();
    Future<T> step<T>(String name, Future<T> Function() f, {int ms = 10000}) async {
      stdout.write('[${sw.elapsedMilliseconds.toString().padLeft(6)}ms] $name ... ');
      try {
        final v = await f().timeout(Duration(milliseconds: ms));
        stdout.writeln('ok${v is PtpResult ? ' -> ${Resp.name(v.code)}' : ''}');
        return v;
      } catch (e) {
        stdout.writeln('FAIL: $e');
        rethrow;
      }
    }

    if (Platform.environment['KATA_LIVE'] != '1') {
      markTestSkipped('live probe is opt-in: KATA_LIVE=1 flutter test test/live_probe_test.dart');
      return;
    }
    final host = LibusbHost(pollEvery: const Duration(hours: 1));
    final devs = await step('listDevices', host.listDevices);
    if (devs.isEmpty) {
      stdout.writeln('no camera attached — skipping');
      await host.dispose();
      return;
    }
    stdout.writeln('         ${devs.map((d) => d.idString).toList()}');
    try {
      await step('open ${devs.first.name}', () => host.open(devs.first.name));
      final ptp = PtpTransport(host.link);
      PtpResult r;
      try {
        r = await step('OpenSession', () => ptp.sendCommand(Op.openSession, [1]));
      } catch (_) {
        // wedged endpoint: port-reset, reopen, retry (mirrors CameraService recovery)
        await step('resetDevice', host.resetDevice, ms: 15000);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final again = await step('listDevices#2', host.listDevices);
        expect(again, isNotEmpty);
        await step('open#2 ${again.first.name}', () => host.open(again.first.name));
        ptp.resetTransactionIds();
        r = await step('OpenSession (after reset)', () => ptp.sendCommand(Op.openSession, [1]));
      }
      if (r.code == Resp.sessionAlreadyOpen) {
        await step('CloseSession (stale)', () => ptp.sendCommand(Op.closeSession));
        ptp.resetTransactionIds();
        r = await step('OpenSession#2', () => ptp.sendCommand(Op.openSession, [1]));
      }
      expect(r.ok, isTrue);
      final info = await step('GetDeviceInfo', () => ptp.sendCommand(Op.getDeviceInfo));
      final di = DeviceInfo.parse(info.data);
      stdout.writeln('         model: ${di.model} · props=${di.properties.length} · D18C=${di.properties.contains(0xD18C)}');
      await step('GetDevicePropValue D18C', () => ptp.sendCommand(Op.getDevicePropValue, [0xD18C]));
      await step('CloseSession (polite)', () => ptp.sendCommand(Op.closeSession));
    } finally {
      await step('host close', () async => host.close());
      await host.dispose();
    }
  });
}
