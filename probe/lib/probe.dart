import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fuji/preset.dart';
import 'ptp/binary.dart';
import 'ptp/codes.dart';
import 'ptp/device_info.dart';
import 'ptp/transport.dart';
import 'ptp/usb_bridge.dart';

/// Drives the probe: connect → device info → slot dump → test write.
/// Everything it learns goes to [log] so the user can copy/paste it.
class ProbeSession extends ChangeNotifier {
  final UsbBridge _usb = UsbBridge();
  late final PtpTransport _ptp = PtpTransport(_usb, log: _log);

  final List<String> lines = [];
  bool busy = false;
  bool connected = false;
  bool sessionOpen = false;
  DeviceInfo? info;
  UsbDeviceInfo? device;

  String get logText => lines.join('\n');

  void _log(String s) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    lines.add('[$ts] $s');
    notifyListeners();
  }

  void clearLog() {
    lines.clear();
    notifyListeners();
  }

  Future<T> _run<T>(String what, Future<T> Function() f) async {
    if (busy) throw StateError('busy');
    busy = true;
    notifyListeners();
    try {
      _log('=== $what ===');
      return await f();
    } catch (e, st) {
      _log('!! $what failed: $e');
      if (kDebugMode) _log(st.toString().split('\n').take(4).join(' | '));
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ connect

  Future<void> connect() => _run('CONNECT', () async {
        final devices = await _usb.listDevices();
        _log('USB devices visible to app: ${devices.length}');
        for (final d in devices) {
          _log('  ${d.idString} ${d.manufacturer ?? ''} ${d.product ?? ''} perm=${d.hasPermission} path=${d.name}');
          for (final i in d.interfaces) {
            _log('     $i');
          }
        }
        final fuji = devices.where((d) => d.vid == fujiVendorId).toList();
        if (fuji.isEmpty) {
          _log('No Fujifilm (04cb) device found. Check: cable is data-capable, camera ON, '
              'CONNECTION MODE = USB RAW CONV./BACKUP RESTORE, USB POWER SUPPLY/COMM = POWER SUPPLY OFF/COMM ON.');
          return;
        }
        final d = fuji.first;
        device = d;
        if (!d.hasPermission) {
          _log('Requesting USB permission…');
          final ok = await _usb.requestPermission(d.name);
          _log('Permission granted: $ok');
          if (!ok) return;
        }
        final o = await _usb.open(d.name);
        _log('Opened: interface=${o['interfaceId']} epIn=0x${(o['epIn'] as int).toRadixString(16)} '
            'epOut=0x${(o['epOut'] as int).toRadixString(16)} maxPkt=${o['maxPacketIn']}/${o['maxPacketOut']}');
        connected = true;
        _ptp.resetTransactionIds();

        await _openSession();
        await _readDeviceInfo();
      });

  Future<void> _openSession() async {
    var r = await _ptp.sendCommand(Op.openSession, [1]);
    _log('OpenSession(1) → ${Resp.name(r.code)}');
    if (r.code == Resp.sessionAlreadyOpen) {
      _log('Stale session: CloseSession + USB re-open, retry…');
      try {
        await _ptp.sendCommand(Op.closeSession);
      } catch (_) {}
      await _usb.close();
      await _usb.open(device!.name);
      _ptp.resetTransactionIds();
      r = await _ptp.sendCommand(Op.openSession, [1]);
      _log('OpenSession(1) retry → ${Resp.name(r.code)}');
    }
    sessionOpen = r.ok;
  }

  Future<void> _readDeviceInfo() async {
    final r = await _ptp.sendCommand(Op.getDeviceInfo);
    _log('GetDeviceInfo → ${Resp.name(r.code)} (${r.data.length} bytes)');
    if (!r.ok) return;
    final di = DeviceInfo.parse(r.data);
    info = di;
    _log('Model: ${di.manufacturer} ${di.model}  fw=${di.deviceVersion}  serial=${di.serialNumber}');
    _log('VendorExt: id=0x${di.vendorExtensionId.toRadixString(16)} v${di.vendorExtensionVersion} "${di.vendorExtensionDesc}"');
    _log('Operations (${di.operations.length}): ${di.operations.map(hex16).join(' ')}');
    _log('Events (${di.events.length}): ${di.events.map(hex16).join(' ')}');
    _log('Properties (${di.properties.length}): ${di.properties.map(hex16).join(' ')}');

    String yn(int p) => di.supportsProp(p) ? '✅' : '❌';
    _log('Preset props: D18C(slot) ${yn(0xD18C)}  D18D(name) ${yn(0xD18D)}  D192(filmsim) ${yn(0xD192)}');
    final have = <int>[];
    final miss = <int>[];
    for (var p = FujiProp.presetFirst; p <= FujiProp.presetLast; p++) {
      (di.supportsProp(p) ? have : miss).add(p);
    }
    _log('D18E–D1A5 advertised: ${have.length}/24${miss.isEmpty ? '' : '  missing: ${miss.map(hex16).join(' ')}'}');
    _log('RAW-conv props: D185 ${yn(0xD185)}  D183 ${yn(0xD183)}   CurrentState D212 ${yn(0xD212)}');
    _log('Vendor ops: 0x900C ${di.supportsOp(0x900C) ? '✅' : '❌'}  0x900D ${di.supportsOp(0x900D) ? '✅' : '❌'}');
    _log('SetDevicePropValue(0x1016) supported: ${di.supportsOp(Op.setDevicePropValue) ? '✅' : '❌'}');
  }

  // ------------------------------------------------------------ helpers

  Future<PtpResult> _get(int prop) => _ptp.sendCommand(Op.getDevicePropValue, [prop]);

  Future<PtpResult> _setU16(int prop, int v) {
    final w = ByteWriter()..u16(v);
    return _ptp.sendDataCommand(Op.setDevicePropValue, [prop], w.toBytes());
  }

  Future<PtpResult> _setBytes(int prop, Uint8List b) => _ptp.sendDataCommand(Op.setDevicePropValue, [prop], b);

  String _fmtProp(int prop, PtpResult r) {
    if (!r.ok) return '${hex16(prop)} ${FujiProp.name(prop).padRight(20)} → ${Resp.name(r.code)}';
    final v = decodePropValue(r.data);
    final desc = describePresetValue(prop, v);
    return '${hex16(prop)} ${FujiProp.name(prop).padRight(20)} [${hex(r.data)}] = $v${desc != null ? '  ($desc)' : ''}';
  }

  // ------------------------------------------------------------ slot dump

  Future<void> readSlots({int maxSlot = 7}) => _run('READ SLOTS', () async {
        _requireSession();
        final orig = await _get(FujiProp.presetSlot);
        _log('Current D18C (slot) → ${Resp.name(orig.code)} ${orig.ok ? decodePropValue(orig.data) : ''}');
        final origSlot = orig.ok && orig.data.length >= 2 ? (decodePropValue(orig.data) as int) : 1;

        for (var slot = 1; slot <= maxSlot; slot++) {
          final s = await _setU16(FujiProp.presetSlot, slot);
          _log('--- Set D18C=$slot → ${Resp.name(s.code)}');
          if (!s.ok) {
            if (slot == 1) {
              _log('Slot select not accepted — camera may not support preset props in this mode.');
              break;
            }
            continue; // X-S20 has C1–C4; higher slots may be rejected
          }
          await Future<void>.delayed(const Duration(milliseconds: 120));
          final back = await _get(FujiProp.presetSlot);
          _log('    readback D18C = ${back.ok ? decodePropValue(back.data) : Resp.name(back.code)}');
          final name = await _get(FujiProp.presetName);
          _log('    ${_fmtProp(FujiProp.presetName, name)}');
          for (var p = FujiProp.presetFirst; p <= FujiProp.presetLast; p++) {
            final r = await _get(p);
            _log('    ${_fmtProp(p, r)}');
          }
        }
        final rs = await _setU16(FujiProp.presetSlot, origSlot);
        _log('Restored D18C=$origSlot → ${Resp.name(rs.code)}');
      });

  // ------------------------------------------------------------ dump every vendor prop

  Future<void> dumpAllProps() => _run('DUMP ALL 0xDxxx PROPS', () async {
        _requireSession();
        final di = info!;
        final props = di.properties.where((p) => p >= 0xD000).toList()..sort();
        _log('${props.length} vendor props');
        for (final p in props) {
          if (p == 0xD185) {
            _log('${hex16(p)} RawConvProfile (skipped — large)');
            continue;
          }
          try {
            final r = await _get(p);
            _log(_fmtProp(p, r));
          } catch (e) {
            _log('${hex16(p)} !! $e');
          }
        }
      });

  // ------------------------------------------------------------ test write

  /// Writes only the film simulation of [slot] and reads it back.
  Future<void> testWriteFilmSim(int slot, int filmSim) => _run('TEST WRITE C$slot film sim → ${filmSimLabels[filmSim]}', () async {
        _requireSession();
        final s = await _setU16(FujiProp.presetSlot, slot);
        _log('Set D18C=$slot → ${Resp.name(s.code)}');
        if (!s.ok) return;
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final before = await _get(FujiProp.filmSimulation);
        _log('Before: ${_fmtProp(FujiProp.filmSimulation, before)}');
        final name = await _get(FujiProp.presetName);
        _log('Name:   ${_fmtProp(FujiProp.presetName, name)}');

        final w = await _setU16(FujiProp.filmSimulation, filmSim);
        _log('Set D192=$filmSim → ${Resp.name(w.code)}');

        final after = await _get(FujiProp.filmSimulation);
        _log('After:  ${_fmtProp(FujiProp.filmSimulation, after)}');

        final stuck = after.ok && after.data.length >= 2 && decodePropValue(after.data) == filmSim;
        _log(stuck
            ? '>>> Camera reports the new value. NOW CHECK THE CAMERA LCD: C$slot should show ${filmSimLabels[filmSim]}. '
                'If the LCD still shows the old sim, try: power-cycle camera, or re-select C$slot on the dial/menu.'
            : '>>> Value did NOT stick over PTP (resp=${Resp.name(w.code)}). This is the FujiStyle symptom.');
      });

  /// Writes a preset name (D18D) and reads it back — the other "does writing work at all" check.
  Future<void> testWriteName(int slot, String name) => _run('TEST WRITE C$slot name → "$name"', () async {
        _requireSession();
        final s = await _setU16(FujiProp.presetSlot, slot);
        _log('Set D18C=$slot → ${Resp.name(s.code)}');
        if (!s.ok) return;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final before = await _get(FujiProp.presetName);
        _log('Before: ${_fmtProp(FujiProp.presetName, before)}');
        final w = await _setBytes(FujiProp.presetName, packPtpString(name));
        _log('Set D18D → ${Resp.name(w.code)}');
        final after = await _get(FujiProp.presetName);
        _log('After:  ${_fmtProp(FujiProp.presetName, after)}');
      });

  // ------------------------------------------------------------ misc

  Future<void> readCurrentState() => _run('READ D212', () async {
        _requireSession();
        final r = await _get(FujiProp.currentState);
        _log(_fmtProp(FujiProp.currentState, r));
      });

  Future<void> disconnect() => _run('DISCONNECT', () async {
        if (sessionOpen) {
          try {
            final r = await _ptp.sendCommand(Op.closeSession);
            _log('CloseSession → ${Resp.name(r.code)}');
          } catch (e) {
            _log('CloseSession error: $e');
          }
        }
        await _usb.close();
        sessionOpen = false;
        connected = false;
        info = null;
        _log('USB closed');
      });

  void _requireSession() {
    if (!connected || !sessionOpen) throw StateError('not connected / session not open — press Connect first');
  }
}
