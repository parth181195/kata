// Human-readable decoding of Fujifilm preset properties (D18E–D1A5).
// Encodings per FilmKit's reverse engineering (confirmed on X100VI).

const filmSimLabels = <int, String>{
  1: 'Provia',
  2: 'Velvia',
  3: 'Astia',
  4: 'Pro Neg. Hi',
  5: 'Pro Neg. Std',
  6: 'Monochrome',
  7: 'Monochrome+Ye',
  8: 'Monochrome+R',
  9: 'Monochrome+G',
  10: 'Sepia',
  11: 'Classic Chrome',
  12: 'Acros',
  13: 'Acros+Ye',
  14: 'Acros+R',
  15: 'Acros+G',
  16: 'Eterna',
  17: 'Classic Neg',
  18: 'Eterna Bleach Bypass',
  19: 'Nostalgic Neg',
  20: 'Reala Ace',
};

const monochromeSims = {6, 7, 8, 9, 10, 12, 13, 14, 15};

const wbLabels = <int, String>{
  0x0000: 'As Shot',
  0x0002: 'Auto',
  0x0004: 'Daylight',
  0x0006: 'Incandescent',
  0x0008: 'Underwater',
  0x8001: 'Fluorescent 1',
  0x8002: 'Fluorescent 2',
  0x8003: 'Fluorescent 3',
  0x8006: 'Shade',
  0x8007: 'Color Temp',
  0x8008: 'Custom 1?',
  0x8009: 'Custom 2?',
  0x800A: 'Custom 3?',
  0x8020: 'Auto (white priority)?',
  0x8021: 'Auto (ambience priority)',
};

const grainLabels = <int, String>{1: 'Off', 2: 'Weak/Small', 3: 'Strong/Small', 4: 'Weak/Large', 5: 'Strong/Large'};
const effectLabels = <int, String>{1: 'Off', 2: 'Weak', 3: 'Strong'};

const nrDecode = <int, int>{
  0x8000: -4, 0x7000: -3, 0x4000: -2, 0x3000: -1,
  0x2000: 0, 0x1000: 1, 0x0000: 2, 0x6000: 3, 0x5000: 4,
};

String fmtTone(int raw) {
  if (raw == -32768 || raw == 0x8000) return '(unset 0x8000)';
  final v = raw / 10;
  return (v >= 0 ? '+' : '') + v.toStringAsFixed(1);
}

/// Decode a 2-byte preset property (given as signed int16) to a label.
/// Returns null if no decoder is known for [prop].
String? describePresetValue(int prop, Object value) {
  if (value is String) return '"$value"';
  if (value is! int) return null;
  final u = value & 0xFFFF;
  switch (prop) {
    case 0xD192:
      return filmSimLabels[value] ?? '? ($value)';
    case 0xD199:
      return wbLabels[u] ?? '? (0x${u.toRadixString(16).toUpperCase()})';
    case 0xD19C:
      return value > 0 ? '${value}K' : 'n/a';
    case 0xD19A:
    case 0xD19B:
      return (value >= 0 ? '+' : '') + value.toString();
    case 0xD190:
      return 'DR$value%';
    case 0xD193:
    case 0xD194:
    case 0xD19D:
    case 0xD19E:
    case 0xD19F:
    case 0xD1A0:
    case 0xD1A2:
      return fmtTone(value);
    case 0xD1A1:
      final d = nrDecode[u];
      return d == null ? '? (0x${u.toRadixString(16).toUpperCase()})' : (d > 0 ? '+$d' : '$d');
    case 0xD195:
      return grainLabels[value] ?? '? ($value)';
    case 0xD196:
    case 0xD197:
    case 0xD198:
      return effectLabels[value] ?? '? ($value)';
    case 0xD1A3:
      return value == 1 ? 'On' : value == 0 ? 'Off' : '? ($value)';
    case 0xD1A4:
      return value == 1 ? 'sRGB' : value == 2 ? 'AdobeRGB' : '? ($value)';
    default:
      return null;
  }
}
