import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

enum CameraFailure { noDevice, permissionDenied, claimFailed, sessionFailed, notPresetCapable, io }

sealed class CameraState {
  const CameraState();
}

class CameraDisconnected extends CameraState {
  const CameraDisconnected({this.reason});
  final CameraFailure? reason;
}

class CameraConnecting extends CameraState {
  const CameraConnecting(this.step);
  final String step;
}

class CameraReady extends CameraState {
  const CameraReady({required this.caps, required this.slots, this.busyWith});
  final CameraCapabilities caps;
  final List<CameraPreset> slots; // index 0 = C1
  final String? busyWith;
  bool get busy => busyWith != null;
  CameraReady copyWith({List<CameraPreset>? slots, String? busyWith, bool clearBusy = false}) =>
      CameraReady(caps: caps, slots: slots ?? this.slots, busyWith: clearBusy ? null : (busyWith ?? this.busyWith));
}

class CameraFailed extends CameraState {
  const CameraFailed(this.reason, [this.detail]);
  final CameraFailure reason;
  final String? detail;
}

/// Android talks USB through the platform bridge; desktop goes straight to libusb.
final usbHostProvider = Provider<UsbHost>((_) {
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) return LibusbHost();
  return UsbBridge();
});

typedef FujiCameraFactory = FujiCamera Function(UsbLink link, Future<void> Function() reopenUsb);
final fujiCameraFactoryProvider = Provider<FujiCameraFactory>(
  (_) => (link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen),
);

final cameraServiceProvider = NotifierProvider<CameraService, CameraState>(CameraService.new);

/// Connection state machine over [FujiCamera]; the only camera API the UI uses.
class CameraService extends Notifier<CameraState> {
  FujiCamera? _cam;
  String? _deviceName;
  StreamSubscription<UsbEvent>? _sub;
  Timer? _heartbeat;

  @override
  CameraState build() {
    _sub ??= ref.read(usbHostProvider).events.listen(_onUsbEvent);
    ref.onDispose(() {
      _sub?.cancel();
      _heartbeat?.cancel();
    });
    return const CameraDisconnected();
  }

  UsbHost get _usb => ref.read(usbHostProvider);

  Future<void> connect() => _connect(canReset: true);

  Future<void> _connect({required bool canReset}) async {
    final devices = await _usb.listDevices();
    final fuji = devices.where((d) => d.vid == fujiVendorId).toList();
    if (fuji.isEmpty) {
      state = const CameraDisconnected(reason: CameraFailure.noDevice);
      return;
    }
    final d = fuji.first;
    _deviceName = d.name;
    state = const CameraConnecting('permission');
    if (!d.hasPermission && !await _usb.requestPermission(d.name)) {
      state = const CameraFailed(CameraFailure.permissionDenied);
      return;
    }
    try {
      state = const CameraConnecting('usb');
      await _usb.open(d.name);
    } catch (e) {
      state = CameraFailed(CameraFailure.claimFailed, '$e');
      return;
    }
    final cam = ref.read(fujiCameraFactoryProvider)(_usb.link, () async {
      await _usb.close();
      await _usb.open(d.name);
    });
    _cam = cam;
    try {
      state = const CameraConnecting('session');
      await cam.openSession();
      final caps = await cam.discoverCapabilities();
      if (!caps.presetProtocol) {
        await _release();
        state = const CameraFailed(CameraFailure.notPresetCapable);
        return;
      }
      state = const CameraConnecting('slots');
      final slots = await cam.readAllSlots();
      state = CameraReady(caps: caps, slots: slots);
      _startHeartbeat();
    } on FujiCameraException catch (e) {
      await _release();
      state = CameraFailed(CameraFailure.sessionFailed, e.message);
    } catch (e) {
      if (canReset && '$e'.contains('bulk')) {
        // Endpoint wedged (e.g. host died mid-transfer and the body never saw CloseSession):
        // port-reset the device, let it re-enumerate, and try once more from scratch.
        state = const CameraConnecting('reset');
        try {
          await _usb.resetDevice();
        } catch (_) {}
        await _release(politely: false);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return _connect(canReset: false);
      }
      await _release(politely: false);
      state = CameraFailed(CameraFailure.io, '$e');
    }
  }

  /// Drop the claim (and, politely, the PTP session) so the camera returns to its own
  /// menu — and, with a cable in, to charging. Impolite mode skips CloseSession when the
  /// transport is already dead so we don't block on timeouts.
  Future<void> _release({bool politely = true}) async {
    _heartbeat?.cancel();
    final cam = _cam;
    _cam = null;
    if (politely && cam != null) {
      try {
        await cam.closeSession();
      } catch (_) {}
    }
    try {
      await _usb.close();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await _release();
    state = const CameraDisconnected();
  }

  Future<void> refreshSlots() async {
    final s = state;
    final cam = _cam;
    if (s is! CameraReady || cam == null) return;
    state = s.copyWith(busyWith: 'Reading slots');
    try {
      final slots = await cam.readAllSlots();
      state = CameraReady(caps: s.caps, slots: slots);
    } catch (e) {
      await _release(politely: false);
      state = CameraFailed(CameraFailure.io, '$e');
    }
  }

  Future<WriteResult> writeRecipe(int slot, CameraPreset preset) async {
    final s = state;
    final cam = _cam;
    if (s is! CameraReady || cam == null) throw StateError('camera not ready');
    state = s.copyWith(busyWith: 'Writing C$slot');
    try {
      final result = await cam.writePreset(slot, preset);
      final fresh = await cam.readSlot(slot);
      final slots = [...s.slots];
      slots[slot - 1] = fresh;
      state = CameraReady(caps: s.caps, slots: slots);
      return result;
    } on FujiCameraException {
      // Protocol-level rejection: the session is still healthy — keep the connection.
      state = CameraReady(caps: s.caps, slots: s.slots);
      rethrow;
    } catch (e) {
      await _release(politely: false);
      state = CameraFailed(CameraFailure.io, '$e');
      rethrow;
    }
  }

  void _onUsbEvent(UsbEvent e) {
    if (!e.attached && (e.deviceName == null || e.deviceName == _deviceName)) {
      _heartbeat?.cancel();
      _cam = null;
      _usb.close();
      state = const CameraDisconnected();
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) async {
      final cam = _cam;
      final s = state;
      if (cam == null || s is! CameraReady || s.busy) return;
      if (!await cam.heartbeat()) {
        await _release(politely: false);
        state = const CameraDisconnected(reason: CameraFailure.io);
      }
    });
  }
}
