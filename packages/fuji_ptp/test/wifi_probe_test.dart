@TestOn('linux || mac-os')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

/// The question this answers: over Wi-Fi, does a Fuji body still expose the Custom Settings
/// protocol (0xD18C slot select + 0xD18D–0xD1A5 preset fields) that Kata writes over USB?
///
///   KATA_LIVE=1 KATA_CAM_IP=192.168.0.x fvm flutter test test/wifi_probe_test.dart
///   KATA_LIVE=1 KATA_SUBNET=192.168.0  fvm flutter test test/wifi_probe_test.dart   (scan)
void main() {
  test('live: PTP/IP handshake, device info, and whether the preset props are there', () async {
    if (Platform.environment['KATA_LIVE'] != '1') {
      markTestSkipped('opt-in: KATA_LIVE=1 KATA_CAM_IP=<camera ip> fvm flutter test test/wifi_probe_test.dart');
      return;
    }
    final sw = Stopwatch()..start();
    void say(String m) => stdout.writeln('[${sw.elapsedMilliseconds.toString().padLeft(6)}ms] $m');

    var ip = Platform.environment['KATA_CAM_IP'];
    if (ip == null) {
      final subnet = Platform.environment['KATA_SUBNET'] ?? '192.168.0';
      say('scanning $subnet.0/24 for port ${FujiWifi.commandPort} …');
      final hits = await scanForCameras(subnet);
      say('candidates: $hits');
      if (hits.isEmpty) {
        fail('no host is listening on ${FujiWifi.commandPort} — is the camera in wireless mode and on this network?');
      }
      ip = hits.first;
    }

    say('connecting to $ip:${FujiWifi.commandPort}');
    final t = await PtpIpTransport.connect(ip, clientName: 'Kata', log: (m) => stdout.writeln('        $m'));
    say('handshake ok · session 0x${t.sessionId.toRadixString(16)}');

    try {
      var r = await t.sendCommand(Op.openSession, [1]);
      say('OpenSession -> ${Resp.name(r.code)}');
      if (r.code == Resp.sessionAlreadyOpen) {
        await t.sendCommand(Op.closeSession);
        t.resetTransactionIds();
        r = await t.sendCommand(Op.openSession, [1]);
        say('OpenSession (retry) -> ${Resp.name(r.code)}');
      }
      expect(r.ok, isTrue, reason: 'the camera would not open a PTP session over Wi-Fi');

      final info = await t.sendCommand(Op.getDeviceInfo);
      expect(info.ok, isTrue, reason: 'GetDeviceInfo failed over Wi-Fi');
      final di = DeviceInfo.parse(info.data);
      say('MODEL: ${di.model} · fw ${di.deviceVersion} · ${di.properties.length} properties');

      // The verdict.
      final preset = [for (var p = 0xD18C; p <= 0xD1A5; p++) if (di.properties.contains(p)) p];
      say('preset props present: ${preset.length}/26 '
          '${preset.map((p) => '0x${p.toRadixString(16).toUpperCase()}').join(' ')}');
      final hasSlotSelect = di.properties.contains(0xD18C);
      say(hasSlotSelect
          ? 'VERDICT: Custom Settings ARE exposed over Wi-Fi — cable-free writing is possible.'
          : 'VERDICT: 0xD18C is absent over Wi-Fi — this body only exposes the wireless command set.');

      // Read one for real, so "present" means "actually answers", not just "listed".
      if (hasSlotSelect) {
        final slot = await t.sendCommand(Op.getDevicePropValue, [0xD18C]);
        say('GetDevicePropValue(0xD18C) -> ${Resp.name(slot.code)} ${slot.data}');
        final name = await t.sendCommand(Op.getDevicePropValue, [0xD18D]);
        say('GetDevicePropValue(0xD18D) -> ${Resp.name(name.code)} (${name.data.length}B)');
      } else {
        // What DOES it offer? Useful either way.
        say('exposed props: ${di.properties.map((p) => '0x${p.toRadixString(16)}').join(' ')}');
        say('operations: ${di.operations.map((o) => '0x${o.toRadixString(16)}').join(' ')}');
      }
    } finally {
      try {
        await t.sendCommand(Op.closeSession).timeout(const Duration(seconds: 3));
      } catch (_) {}
      await t.close();
      say('closed');
    }
  });
}
