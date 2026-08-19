import 'dart:typed_data';

import 'binary.dart';

/// A PTP/USB container: 12-byte header + (params | data).
class PtpContainer {
  PtpContainer({
    required this.type,
    required this.code,
    required this.transactionId,
    List<int>? params,
    Uint8List? data,
  })  : params = params ?? const [],
        data = data ?? Uint8List(0);

  final int type;
  final int code;
  final int transactionId;
  final List<int> params;
  final Uint8List data;

  static const headerLength = 12;

  Uint8List pack() {
    final payloadLen = data.isNotEmpty ? data.length : params.length * 4;
    final w = ByteWriter()
      ..u32(headerLength + payloadLen)
      ..u16(type)
      ..u16(code)
      ..u32(transactionId);
    if (data.isNotEmpty) {
      w.bytes(data);
    } else {
      for (final p in params) {
        w.u32(p);
      }
    }
    return w.toBytes();
  }

  /// Total length declared in the header of a (possibly partial) buffer.
  static int declaredLength(Uint8List buf) {
    if (buf.length < 4) throw const FormatException('buffer shorter than length field');
    return ByteData.sublistView(buf).getUint32(0, Endian.little);
  }

  static PtpContainer unpack(Uint8List buf) {
    if (buf.length < headerLength) {
      throw FormatException('container too short: ${buf.length} bytes');
    }
    final r = ByteReader(buf);
    final len = r.u32();
    final type = r.u16();
    final code = r.u16();
    final tid = r.u32();
    final payload = buf.sublist(headerLength, len.clamp(headerLength, buf.length));
    if (type == 1 || type == 3 || type == 4) {
      final params = <int>[];
      final pr = ByteReader(payload);
      while (pr.remaining >= 4) {
        params.add(pr.u32());
      }
      return PtpContainer(type: type, code: code, transactionId: tid, params: params);
    }
    return PtpContainer(type: type, code: code, transactionId: tid, data: payload);
  }

  @override
  String toString() =>
      'PtpContainer(type=$type code=0x${code.toRadixString(16)} tid=$transactionId params=$params data=${data.length}B)';
}
