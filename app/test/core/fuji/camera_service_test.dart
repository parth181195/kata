import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';

class FakeUsbHost implements UsbHost {
  FakeUsbHost(this.body, {this.present = true, this.grant = true});
  final FakeFujiBody body;
  bool present;
  bool grant;
  bool opened = false;
  final ctrl = StreamController<UsbEvent>.broadcast();

  @override
  Future<List<UsbDeviceInfo>> listDevices() async => present
      ? [
          UsbDeviceInfo(
              name: '/dev/bus/usb/001/002', vid: 0x04CB, pid: 0x02F7, product: 'USB PTP Camera', manufacturer: 'FUJIFILM',
              hasPermission: grant, interfaces: [UsbInterfaceInfo(0, 6, 1, 1, 0x81, 0x01)])
        ]
      : [];
  @override
  Future<bool> requestPermission(String name) async => grant;
  @override
  Future<Map> open(String name, {int? interfaceId}) async {
    opened = true;
    return {'interfaceId': 0, 'epIn': 0x81, 'epOut': 1, 'maxPacketIn': 512, 'maxPacketOut': 512};
  }

  @override
  Future<void> close() async => opened = false;
  @override
  Stream<UsbEvent> get events => ctrl.stream;
  @override
  UsbLink get link => body;
}

ProviderContainer make(FakeUsbHost host) => ProviderContainer(overrides: [
      usbHostProvider.overrideWithValue(host),
      fujiCameraFactoryProvider.overrideWithValue(
          (link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
    ]);

void main() {
  test('connect -> Ready with caps and slots', () async {
    final host = FakeUsbHost(FakeFujiBody());
    final c = make(host);
    await c.read(cameraServiceProvider.notifier).connect();
    final s = c.read(cameraServiceProvider);
    expect(s, isA<CameraReady>());
    final r = s as CameraReady;
    expect(r.caps.slotCount, 4);
    expect(r.slots.length, 4);
  });

  test('no device -> Disconnected(noDevice); permission denied -> Failed(permissionDenied)', () async {
    final c1 = make(FakeUsbHost(FakeFujiBody(), present: false));
    await c1.read(cameraServiceProvider.notifier).connect();
    expect((c1.read(cameraServiceProvider) as CameraDisconnected).reason, CameraFailure.noDevice);

    final c2 = make(FakeUsbHost(FakeFujiBody(), grant: false));
    await c2.read(cameraServiceProvider.notifier).connect();
    expect((c2.read(cameraServiceProvider) as CameraFailed).reason, CameraFailure.permissionDenied);
  });

  test('body without D18C -> Failed(notPresetCapable)', () async {
    final c = make(FakeUsbHost(FakeFujiBody(supported: {0xD212, 0xD185})));
    await c.read(cameraServiceProvider.notifier).connect();
    expect((c.read(cameraServiceProvider) as CameraFailed).reason, CameraFailure.notPresetCapable);
  });

  test('writeRecipe goes through, state returns to Ready with refreshed slot', () async {
    final host = FakeUsbHost(FakeFujiBody());
    final c = make(host);
    final n = c.read(cameraServiceProvider.notifier);
    await n.connect();
    final res = await n.writeRecipe(2, const CameraPreset(name: 'K', filmSim: FilmSim.classicChrome, dynamicRange: 400));
    expect(res.ok, isTrue);
    final s = c.read(cameraServiceProvider) as CameraReady;
    expect(s.slots[1].filmSim, FilmSim.classicChrome);
    expect(host.body.slots[2]![0xD192], Uint8List.fromList([11, 0]));
  });

  test('detach event resets to Disconnected', () async {
    final host = FakeUsbHost(FakeFujiBody());
    final c = make(host);
    final n = c.read(cameraServiceProvider.notifier);
    await n.connect();
    host.ctrl.add(const UsbEvent(attached: false, deviceName: '/dev/bus/usb/001/002'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(cameraServiceProvider), isA<CameraDisconnected>());
    expect(host.opened, isFalse);
  });
}
