import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/src/fuji/camera_preset.dart';
import 'package:fuji_ptp/src/fuji/fuji_camera.dart';
import 'package:fuji_ptp/src/fuji/fuji_props.dart';
import 'package:fuji_ptp/src/ptp/transport.dart';

import 'package:fuji_ptp/testing.dart';

FujiCamera cam(FakeFujiBody body, {Future<void> Function()? reopen}) =>
    FujiCamera(PtpTransport(body), reopenUsb: reopen, slotSettle: Duration.zero);

void main() {
  test('open session, device info, capabilities with 4 slots and no D198', () async {
    final body = FakeFujiBody();
    final c = cam(body);
    await c.openSession();
    final caps = await c.discoverCapabilities();
    expect(caps.model, 'X-S20');
    expect(caps.slotCount, 4);
    expect(caps.hasSmoothSkin, isFalse);
    expect(caps.presetProtocol, isTrue);
    expect(body.currentSlot, 1); // restored after probing
  });

  test('stale session (0x201E) is recovered via close + reopen + retry', () async {
    final body = FakeFujiBody(staleSessionOnce: true);
    var reopened = 0;
    final c = cam(body, reopen: () async => reopened++);
    await c.openSession();
    expect(reopened, 1);
    expect(body.sessionOpen, isTrue);
    expect(body.log.where((l) => l.startsWith('1002')).length, 2);
  });

  test('readSlot decodes what the body holds', () async {
    final body = FakeFujiBody();
    body.slots[3]![0xD192] = Uint8List.fromList([12, 0]);
    body.slots[3]![0xD19D] = Uint8List.fromList([0xF6, 0xFF]);
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final p = await c.readSlot(3);
    expect(p.filmSim, FilmSim.acros);
    expect(p.highlightX10, -10);
    expect(body.currentSlot, 3);
  });

  test('writePreset writes in order, verifies, copies passthrough bytes from the slot', () async {
    final body = FakeFujiBody();
    body.slots[2]![0xD1A5] = Uint8List.fromList([9, 0]);
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    body.log.clear();
    final r = await c.writePreset(2, const CameraPreset(name: 'Test K', filmSim: FilmSim.classicChrome, dynamicRange: 400, highlightX10: 15));
    expect(r.ok, isTrue);
    expect(r.warnings, isEmpty);
    expect(body.slots[2]![0xD192], Uint8List.fromList([11, 0]));
    expect(body.slots[2]![0xD19D], Uint8List.fromList([15, 0]));
    expect(body.slots[2]![0xD1A5], Uint8List.fromList([9, 0])); // untouched passthrough
    final readBack = await c.readSlot(2);
    expect(readBack.name, 'Test K');
    final setOrder = body.log.where((l) => l.startsWith('1016')).map((l) => l.split(' ')[1]).toList();
    expect(setOrder.first, '[53644]'); // 0xD18C slot select first
    expect(setOrder[1], '[53645]'); // 0xD18D name
  });

  test('rejected optional prop becomes a warning; verify mismatch fails', () async {
    final body = FakeFujiBody()..rejectWrites.add(0xD1A2);
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final r = await c.writePreset(1, const CameraPreset(name: 'A', filmSim: 1));
    expect(r.ok, isTrue);
    expect(r.warnings.single, contains('D1A2'));
    expect(r.skipped, [0xD1A2]);

    final body2 = FakeFujiBody()..corruptOnWrite.add(0xD19E);
    final c2 = cam(body2);
    await c2.openSession();
    await c2.discoverCapabilities();
    final r2 = await c2.writePreset(1, const CameraPreset(name: 'A', filmSim: 1, shadowX10: 10));
    expect(r2.ok, isFalse);
    expect(r2.warnings.any((w) => w.contains('verify')), isTrue);
  });

  test('writing to a slot beyond slotCount throws', () async {
    final body = FakeFujiBody();
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    expect(() => c.writePreset(5, const CameraPreset(name: 'A', filmSim: 1)), throwsA(isA<FujiCameraException>()));
  });

  test('calls are serialized (job queue)', () async {
    final body = FakeFujiBody();
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final results = await Future.wait([c.readSlot(1), c.readSlot(2), c.readSlot(3)]);
    expect(results.length, 3);
    final selects = body.log.where((l) => l.startsWith('1016 [53644]')).toList();
    expect(selects.length, greaterThanOrEqualTo(3));
  });

  test('body refusing the name falls back to empty; settings still written', () async {
    final body = FakeFujiBody()..nameMaxLen = 0;
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final r = await c.writePreset(1, const CameraPreset(name: 'Kodachrome 64', filmSim: 1, highlightX10: 15));
    expect(r.ok, isTrue);
    expect(r.written, contains(0xD18D));
    expect(r.warnings.any((w) => w.contains('name')), isTrue);
    expect(body.slots[1]![0xD19D], Uint8List.fromList([15, 0]));
    expect((await c.readSlot(1)).name, '');
  });

  test('body that accepts but silently drops the name only warns', () async {
    final body = FakeFujiBody()..dropNameOnWrite = true;
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final r = await c.writePreset(1, const CameraPreset(name: 'Test K', filmSim: 1));
    expect(r.ok, isTrue); // cosmetic: never fails a write
    expect(r.warnings.any((w) => w.contains('name')), isTrue);
  });

  test('writePreset reports per-field progress 0..total', () async {
    final body = FakeFujiBody();
    final c = cam(body);
    await c.openSession();
    await c.discoverCapabilities();
    final ticks = <(int, int)>[];
    await c.writePreset(1, const CameraPreset(name: 'A', filmSim: 1, highlightX10: 15), onProgress: (d, t) => ticks.add((d, t)));
    expect(ticks.first, (0, ticks.first.$2));
    expect(ticks.last.$1, ticks.last.$2);
    expect(ticks.map((e) => e.$1), List.generate(ticks.length, (i) => i));
    expect(ticks.every((e) => e.$2 == ticks.first.$2), isTrue);
  });
}
