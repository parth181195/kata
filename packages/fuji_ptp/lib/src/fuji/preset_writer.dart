import 'dart:typed_data';

import '../ptp/binary.dart';
import 'camera_preset.dart';
import 'fuji_props.dart';
import 'preset_codec.dart';

class CameraCapabilities {
  const CameraCapabilities({
    required this.model,
    required this.firmware,
    required this.pid,
    required this.supportedProps,
    required this.slotCount,
  });
  final String model;
  final String firmware;
  final int pid;
  final Set<int> supportedProps;
  final int slotCount;

  bool supports(int code) => supportedProps.contains(code);
  bool get presetProtocol => supports(0xD18C);
  bool get hasSmoothSkin => supports(0xD198);

  @override
  String toString() =>
      'CameraCapabilities($model fw=$firmware pid=0x${pid.toRadixString(16)} slots=$slotCount props=${supportedProps.length})';
}

class PropWrite {
  const PropWrite(this.code, this.bytes, {this.fatal = false});
  final int code;
  final Uint8List bytes;
  final bool fatal;
}

class WriteResult {
  const WriteResult({
    required this.ok,
    required this.slot,
    this.warnings = const [],
    this.written = const [],
    this.skipped = const [],
    this.skipReasons = const {},
    this.mismatched = const [],
    this.needsDialFlick = true,
  });
  final bool ok;
  final int slot;
  final List<String> warnings;
  final List<int> written;
  final List<int> skipped;

  /// Skipped property code -> the PTP response the camera answered with. The difference
  /// between "this body has no such setting" and "it's locked right now" lives here.
  final Map<int, int> skipReasons;

  /// Props the camera accepted and then read back as something else. [ok] is false when this
  /// isn't empty — the slot doesn't hold what we sent.
  final List<int> mismatched;
  final bool needsDialFlick;
}

/// Turns a [CameraPreset] into the ordered list of property writes for a body with [caps].
class PresetWriter {
  /// X RAW Studio caps preset names at 25 characters; some bodies store none at all.
  static const nameMax = 25;

  /// ASCII-printable only, whitespace collapsed, trimmed, capped at [nameMax] — the safest
  /// superset across bodies. The label is cosmetic; the settings are what matter.
  static String sanitizeName(String name) {
    final ascii = name.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return ascii.length <= nameMax ? ascii : ascii.substring(0, nameMax).trimRight();
  }

  static List<PropWrite> plan(CameraPreset p, CameraCapabilities caps) {
    final encoded = PresetCodec.encode(p);
    final out = <PropWrite>[];
    for (final code in presetWriteOrder) {
      if (code == 0xD18D) {
        out.add(PropWrite(code, packPtpString(sanitizeName(p.name)), fatal: true));
        continue;
      }
      final bytes = encoded[code];
      if (bytes == null) continue; // value-conditional omission
      if (caps.supportedProps.isNotEmpty && !caps.supports(code)) continue; // body lacks it
      out.add(PropWrite(code, bytes));
    }
    return out;
  }
}
