import 'dart:async';
import 'dart:typed_data';

import '../ptp/binary.dart';
import '../ptp/codes.dart';
import '../ptp/device_info.dart';
import '../ptp/transport.dart';
import 'camera_preset.dart';
import 'preset_codec.dart';
import 'preset_writer.dart';

class FujiCameraException implements Exception {
  FujiCameraException(this.message);
  final String message;
  @override
  String toString() => 'FujiCameraException: $message';
}

/// High-level Fujifilm preset protocol over a [PtpTransport]. All public methods are serialized.
class FujiCamera {
  FujiCamera(this._ptp, {Future<void> Function()? reopenUsb, this.slotSettle = const Duration(milliseconds: 120)})
      : _reopenUsb = reopenUsb;

  final PtpSession _ptp;
  final Future<void> Function()? _reopenUsb;
  final Duration slotSettle;

  CameraCapabilities? _caps;
  CameraCapabilities? get caps => _caps;
  DeviceInfo? _info;
  DeviceInfo? get deviceInfo => _info;

  Future<void> _tail = Future.value();

  /// Single-flight job queue.
  Future<T> _job<T>(Future<T> Function() f) {
    final run = _tail.then((_) => f());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  // ------------------------------------------------------------ session

  Future<void> openSession() => _job(() async {
        var r = await _ptp.sendCommand(Op.openSession, [1]);
        if (r.code == Resp.sessionAlreadyOpen) {
          try {
            await _ptp.sendCommand(Op.closeSession);
          } catch (_) {}
          if (_reopenUsb != null) await _reopenUsb();
          _ptp.resetTransactionIds();
          r = await _ptp.sendCommand(Op.openSession, [1]);
        }
        if (!r.ok) throw FujiCameraException('OpenSession failed: ${Resp.name(r.code)}');
      });

  Future<void> closeSession() => _job(() async {
        try {
          await _ptp.sendCommand(Op.closeSession);
        } catch (_) {}
      });

  Future<DeviceInfo> readDeviceInfo() => _job(() async {
        final r = await _ptp.sendCommand(Op.getDeviceInfo);
        if (!r.ok) throw FujiCameraException('GetDeviceInfo failed: ${Resp.name(r.code)}');
        _info = DeviceInfo.parse(r.data);
        return _info!;
      });

  /// Reads DeviceInfo (if needed) and probes the slot count by selecting D18C = 1..7.
  Future<CameraCapabilities> discoverCapabilities() => _job(() async {
        if (_info == null) {
          final r = await _ptp.sendCommand(Op.getDeviceInfo);
          if (!r.ok) throw FujiCameraException('GetDeviceInfo failed: ${Resp.name(r.code)}');
          _info = DeviceInfo.parse(r.data);
        }
        final info = _info!;
        var slots = 0;
        if (info.supportsProp(0xD18C)) {
          final orig = await _get(0xD18C);
          final origSlot = orig.ok && orig.data.length >= 2 ? u16leOf(orig.data) : 1;
          for (var s = 1; s <= 7; s++) {
            final r = await _set(0xD18C, u16le(s));
            if (!r.ok) break;
            slots = s;
          }
          await _set(0xD18C, u16le(origSlot));
        }
        _caps = CameraCapabilities(
          model: info.model,
          firmware: info.deviceVersion,
          pid: 0,
          supportedProps: info.properties.toSet(),
          slotCount: slots,
        );
        return _caps!;
      });

  // ------------------------------------------------------------ slots

  Future<CameraPreset> readSlot(int slot) => _job(() => _readSlotUnlocked(slot));

  Future<List<CameraPreset>> readAllSlots() => _job(() async {
        final caps = _requireCaps();
        final orig = await _get(0xD18C);
        final origSlot = orig.ok && orig.data.length >= 2 ? u16leOf(orig.data) : 1;
        final out = <CameraPreset>[];
        for (var s = 1; s <= caps.slotCount; s++) {
          out.add(await _readSlotUnlocked(s));
        }
        await _set(0xD18C, u16le(origSlot));
        return out;
      });

  Future<CameraPreset> _readSlotUnlocked(int slot) async {
    final caps = _requireCaps();
    if (slot < 1 || slot > caps.slotCount) throw FujiCameraException('slot $slot out of range (1..${caps.slotCount})');
    final sel = await _set(0xD18C, u16le(slot));
    if (!sel.ok) throw FujiCameraException('select slot $slot: ${Resp.name(sel.code)}');
    await Future<void>.delayed(slotSettle);
    final nameR = await _get(0xD18D);
    final name = nameR.ok ? ByteReader(nameR.data).ptpString() : '';
    final raw = <int, Uint8List>{};
    for (var p = 0xD18E; p <= 0xD1A5; p++) {
      if (!caps.supports(p)) continue;
      final r = await _get(p);
      if (r.ok) raw[p] = r.data;
    }
    return PresetCodec.decode(name: name, raw: raw);
  }

  /// [onProgress] reports (fieldsDone, fieldsTotal) as each property lands — drives the
  /// "Writing C5 · 14/22" UI. Called once with (0, total) before the first write.
  Future<WriteResult> writePreset(int slot, CameraPreset preset, {void Function(int done, int total)? onProgress}) => _job(() async {
        final caps = _requireCaps();
        if (slot < 1 || slot > caps.slotCount) throw FujiCameraException('slot $slot out of range (1..${caps.slotCount})');

        // Selects the slot, settles, and reads it: passthrough bytes always come from the slot being overwritten.
        final current = await _readSlotUnlocked(slot);
        final toWrite = preset.copyWith(rawExtras: current.rawExtras);

        final plan = PresetWriter.plan(toWrite, caps);
        final warnings = <String>[];
        final written = <int>[];
        final skipped = <int>[];
        final skipReasons = <int, int>{};
        final writtenBytes = <int, Uint8List>{};
        onProgress?.call(0, plan.length);
        var progressed = 0;
        for (final w in plan) {
          var bytes = w.bytes;
          var r = await _set(w.code, bytes);
          if (!r.ok && w.code == 0xD18D && bytes.length > 1) {
            // Some bodies cap or refuse preset names (X-S20: none). The label is cosmetic —
            // retry with an empty name so the settings still land.
            final rejected = Resp.name(r.code);
            final empty = packPtpString('');
            r = await _set(0xD18D, empty);
            if (r.ok) {
              bytes = empty;
              warnings.add('0xD18D PresetName: name rejected ($rejected); wrote empty — this body may not store names');
            }
          }
          if (r.ok) {
            written.add(w.code);
            writtenBytes[w.code] = bytes;
          } else if (w.fatal) {
            throw FujiCameraException('${hex16(w.code)} (${FujiProp.name(w.code)}) rejected: ${Resp.name(r.code)}');
          } else {
            skipped.add(w.code);
            skipReasons[w.code] = r.code;
            warnings.add('${hex16(w.code)} ${FujiProp.name(w.code)}: rejected (${Resp.name(r.code)})');
          }
          onProgress?.call(++progressed, plan.length);
        }
        // Verify
        var ok = true;
        for (final code in written) {
          final r = await _get(code);
          if (!r.ok) continue;
          final expected = writtenBytes[code]!;
          final got = r.data;
          final same = code == 0xD18D
              ? ByteReader(got).ptpString() == ByteReader(expected).ptpString()
              : got.length >= expected.length && _eq(got.sublist(0, expected.length), expected);
          if (!same) {
            if (code == 0xD18D) {
              // Cosmetic: bodies that store no name read back empty. Never fail the write over it.
              warnings.add("0xD18D PresetName: body kept '${ByteReader(got).ptpString()}' — it may not store names");
            } else {
              ok = false;
              warnings.add('${hex16(code)} ${FujiProp.name(code)}: verify mismatch (wrote ${hex(expected)} read ${hex(got)})');
            }
          }
        }
        return WriteResult(ok: ok, slot: slot, warnings: warnings, written: written, skipped: skipped, skipReasons: skipReasons);
      });

  Future<bool> heartbeat() => _job(() async {
        try {
          final r = await _get(0xD212);
          return r.ok;
        } catch (_) {
          return false;
        }
      });

  // ------------------------------------------------------------ helpers

  CameraCapabilities _requireCaps() {
    final c = _caps;
    if (c == null) throw FujiCameraException('capabilities not discovered');
    if (!c.presetProtocol) throw FujiCameraException('body does not expose custom slots over USB');
    return c;
  }

  Future<PtpResult> _get(int prop) => _ptp.sendCommand(Op.getDevicePropValue, [prop]);
  Future<PtpResult> _set(int prop, Uint8List bytes) => _ptp.sendDataCommand(Op.setDevicePropValue, [prop], bytes);

  static bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
