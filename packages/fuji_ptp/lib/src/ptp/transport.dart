import 'dart:typed_data';

import 'codes.dart';
import 'container.dart';

/// Minimal raw USB bulk link. Implemented by the platform bridge; faked in tests.
abstract class UsbLink {
  Future<int> bulkOut(Uint8List data, {int timeoutMs = 5000});
  Future<Uint8List> bulkIn(int maxLen, {int timeoutMs = 5000});
}

class PtpResult {
  PtpResult(this.code, this.params, this.data);
  final int code;
  final List<int> params;
  final Uint8List data;
  bool get ok => code == Resp.ok;
}

class PtpException implements Exception {
  PtpException(this.message);
  final String message;
  @override
  String toString() => 'PtpException: $message';
}

/// The PTP transaction surface the Fuji layer talks to, so the same camera logic runs over
/// USB bulk ([PtpTransport]) or TCP (`PtpIpTransport`, Wi-Fi).
abstract class PtpSession {
  /// Command with an optional inbound data phase.
  Future<PtpResult> sendCommand(int opcode, [List<int> params, int timeoutMs]);

  /// Command with an outbound data phase (SetDevicePropValue, SendObject…).
  Future<PtpResult> sendDataCommand(int opcode, List<int> params, Uint8List data, [int timeoutMs]);

  /// Start numbering transactions from scratch (after a session is re-opened).
  void resetTransactionIds();
}

/// PTP transaction layer over a [UsbLink].
class PtpTransport implements PtpSession {
  PtpTransport(this.link, {this.readChunk = 64 * 1024, this.log});

  final UsbLink link;
  final int readChunk;
  final void Function(String)? log;
  int _txn = 0;

  @override
  void resetTransactionIds() => _txn = 0;
  int _next() => ++_txn;

  Future<void> _send(PtpContainer c, int timeoutMs) async {
    final bytes = c.pack();
    await link.bulkOut(bytes, timeoutMs: timeoutMs);
  }

  Future<PtpContainer> _recv(int timeoutMs) async {
    var buf = await link.bulkIn(readChunk, timeoutMs: timeoutMs);
    if (buf.length < 4) throw PtpException('short read (${buf.length} bytes)');
    final total = PtpContainer.declaredLength(buf);
    if (total < PtpContainer.headerLength) throw PtpException('bad container length $total');
    if (buf.length < total) {
      final b = BytesBuilder(copy: false)..add(buf);
      while (b.length < total) {
        final more = await link.bulkIn(readChunk, timeoutMs: timeoutMs);
        if (more.isEmpty) throw PtpException('read stalled at ${b.length}/$total');
        b.add(more);
        if (b.length > 128 * 1024 * 1024) throw PtpException('response too large');
      }
      buf = b.toBytes();
    }
    return PtpContainer.unpack(buf);
  }

  /// Command with optional inbound data phase.
  @override
  Future<PtpResult> sendCommand(int opcode, [List<int> params = const [], int timeoutMs = 5000]) async {
    final tid = _next();
    await _send(PtpContainer(type: ContainerType.command, code: opcode, transactionId: tid, params: params), timeoutMs);
    var resp = await _recv(timeoutMs);
    var data = Uint8List(0);
    if (resp.type == ContainerType.data) {
      data = resp.data;
      resp = await _recv(timeoutMs);
    }
    if (resp.type != ContainerType.response) {
      throw PtpException('expected RESPONSE, got type ${resp.type}');
    }
    return PtpResult(resp.code, resp.params, data);
  }

  /// Command with outbound data phase (SetDevicePropValue, SendObject…).
  @override
  Future<PtpResult> sendDataCommand(int opcode, List<int> params, Uint8List data, [int timeoutMs = 5000]) async {
    final tid = _next();
    await _send(PtpContainer(type: ContainerType.command, code: opcode, transactionId: tid, params: params), timeoutMs);
    await _send(PtpContainer(type: ContainerType.data, code: opcode, transactionId: tid, data: data), timeoutMs);
    final resp = await _recv(timeoutMs);
    if (resp.type != ContainerType.response) {
      throw PtpException('expected RESPONSE, got type ${resp.type}');
    }
    return PtpResult(resp.code, resp.params, Uint8List(0));
  }
}
