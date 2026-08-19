import 'dart:typed_data';

/// Little-endian byte writer for PTP payloads.
class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  void u8(int v) => _b.addByte(v & 0xFF);
  void u16(int v) {
    _b.addByte(v & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
  }

  void i16(int v) => u16(v & 0xFFFF);
  void u32(int v) {
    u16(v & 0xFFFF);
    u16((v >> 16) & 0xFFFF);
  }

  void bytes(List<int> b) => _b.add(b);
  void ptpString(String s) => _b.add(packPtpString(s));
  void u16Array(List<int> v) {
    u32(v.length);
    for (final x in v) {
      u16(x);
    }
  }

  Uint8List toBytes() => _b.toBytes();
}

/// Little-endian byte reader for PTP payloads.
class ByteReader {
  ByteReader(this._d) : _v = ByteData.sublistView(_d);
  final Uint8List _d;
  final ByteData _v;
  int pos = 0;

  int get remaining => _d.length - pos;

  int u8() => _d[pos++];
  int u16() {
    final x = _v.getUint16(pos, Endian.little);
    pos += 2;
    return x;
  }

  int i16() {
    final x = _v.getInt16(pos, Endian.little);
    pos += 2;
    return x;
  }

  int u32() {
    final x = _v.getUint32(pos, Endian.little);
    pos += 4;
    return x;
  }

  int i32() {
    final x = _v.getInt32(pos, Endian.little);
    pos += 4;
    return x;
  }

  List<int> u16Array() {
    final n = u32();
    return List.generate(n, (_) => u16());
  }

  Uint8List rest() => _d.sublist(pos);

  /// PTP string: u8 numChars (incl. NUL terminator), then UCS-2LE code units.
  String ptpString() {
    final n = u8();
    if (n == 0) return '';
    final units = <int>[];
    for (var i = 0; i < n; i++) {
      units.add(u16());
    }
    while (units.isNotEmpty && units.last == 0) {
      units.removeLast();
    }
    return String.fromCharCodes(units);
  }
}

/// Encode a PTP string: length byte (chars + NUL) followed by UCS-2LE + NUL.
Uint8List packPtpString(String s) {
  if (s.isEmpty) return Uint8List.fromList([0]);
  final units = s.codeUnits;
  final w = ByteWriter()..u8(units.length + 1);
  for (final u in units) {
    w.u16(u);
  }
  w.u16(0);
  return w.toBytes();
}

/// Decode a raw property payload the way FilmKit does: PTP string if it
/// looks like one, else int16 / int32 / u8, else hex.
Object decodePropValue(Uint8List data) {
  if (data.length >= 3) {
    final n = data[0];
    final expected = 1 + n * 2;
    if (n >= 2 && (expected == data.length || expected == data.length + 1)) {
      try {
        return ByteReader(data).ptpString();
      } catch (_) {}
    }
  }
  if (data.length == 2) return ByteData.sublistView(data).getInt16(0, Endian.little);
  if (data.length == 4) return ByteData.sublistView(data).getInt32(0, Endian.little);
  if (data.length == 1) return data[0];
  return hex(data.sublist(0, data.length > 32 ? 32 : data.length));
}

String hex(List<int> b, {String sep = ' '}) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(sep);

String hex16(int v) => '0x${(v & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';
