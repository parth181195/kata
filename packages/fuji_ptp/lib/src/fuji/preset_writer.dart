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
    this.needsDialFlick = true,
  });
  final bool ok;
  final int slot;
  final List<String> warnings;
  final List<int> written;
  final List<int> skipped;
  final bool needsDialFlick;
}

/// Turns a [CameraPreset] into the ordered list of property writes for a body with [caps].
class PresetWriter {
  static List<PropWrite> plan(CameraPreset p, CameraCapabilities caps) {
    final encoded = PresetCodec.encode(p);
    final out = <PropWrite>[];
    for (final code in presetWriteOrder) {
      if (code == 0xD18D) {
        out.add(PropWrite(code, packPtpString(p.name), fatal: true));
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
