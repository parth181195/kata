import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'transport.dart';

/// PTP/IP packet types (ISO 15740 Annex, as used by Fujifilm on port 55740).
class PtpIpPacket {
  static const initCommandRequest = 1;
  static const initCommandAck = 2;
  static const initEventRequest = 3;
  static const initEventAck = 4;
  static const initFail = 5;
  static const operationRequest = 6;
  static const operationResponse = 7;
  static const event = 8;
  static const startData = 9;
  static const data = 10;
  static const cancel = 11;
  static const endData = 12;
  static const probeRequest = 13;
  static const probeResponse = 14;

  static const names = <int, String>{
    1: 'InitCommandRequest',
    2: 'InitCommandAck',
    3: 'InitEventRequest',
    4: 'InitEventAck',
    5: 'InitFail',
    6: 'OperationRequest',
    7: 'OperationResponse',
    8: 'Event',
    9: 'StartData',
    10: 'Data',
    11: 'Cancel',
    12: 'EndData',
    13: 'ProbeRequest',
    14: 'ProbeResponse',
  };
  static String name(int t) => names[t] ?? '0x${t.toRadixString(16)}';
}

/// One framed PTP/IP packet: 4-byte LE total length, 4-byte LE type, payload.
class PtpIpFrame {
  const PtpIpFrame(this.type, this.payload);
  final int type;
  final Uint8List payload;

  Uint8List pack() {
    final out = Uint8List(8 + payload.length);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, out.length, Endian.little);
    bd.setUint32(4, type, Endian.little);
    out.setRange(8, out.length, payload);
    return out;
  }

  @override
  String toString() => '${PtpIpPacket.name(type)}(${payload.length}B)';
}

/// Fuji's wireless ports. Command/data is the only one the preset protocol needs;
/// events and live view are separate sockets we don't open.
class FujiWifi {
  static const commandPort = 55740;
  static const eventPort = 55741;
  static const streamPort = 55742;
}

/// PTP over TCP (PTP/IP) — the wireless sibling of [PtpTransport]. Speaks the same
/// [PtpSession] surface, so the Fuji preset layer works over either transport.
///
/// Fuji deviates from the letter of PTP/IP in places, so every step logs its raw frame:
/// this doubles as the instrument we use to find out what a body actually allows over Wi-Fi.
class PtpIpTransport implements PtpSession {
  PtpIpTransport._(this._socket, {this.log}) {
    _sub = _socket.listen(_onBytes, onError: _onError, onDone: _onDone);
  }

  final Socket _socket;
  final void Function(String)? log;
  StreamSubscription<Uint8List>? _sub;
  final _buffer = BytesBuilder(copy: false);
  final _frames = StreamController<PtpIpFrame>();
  late final StreamQueue<PtpIpFrame> _q = StreamQueue(_frames.stream);
  int _txn = 0;
  int sessionId = 0;

  /// Connect the command channel and run the init handshake.
  ///
  /// [guid] identifies this client to the camera; bodies that remember paired clients key
  /// off it, so callers should keep one stable GUID per install.
  static Future<PtpIpTransport> connect(
    String host, {
    int port = FujiWifi.commandPort,
    String clientName = 'Kata',
    List<int>? guid,
    Duration timeout = const Duration(seconds: 8),
    void Function(String)? log,
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final t = PtpIpTransport._(socket, log: log);
    await t._init(clientName: clientName, guid: guid ?? _defaultGuid, timeout: timeout);
    return t;
  }

  /// Stable-ish per-install identity; callers should override with a persisted value.
  static final _defaultGuid = List<int>.filled(16, 0)
    ..setRange(0, 4, const [0x4B, 0x41, 0x54, 0x41]); // 'KATA'

  Future<void> _init({required String clientName, required List<int> guid, required Duration timeout}) async {
    final name = _utf16z(clientName);
    final payload = Uint8List(16 + name.length + 4);
    payload.setRange(0, 16, guid);
    payload.setRange(16, 16 + name.length, name);
    ByteData.sublistView(payload).setUint32(16 + name.length, 0x00010000, Endian.little); // protocol v1.0
    _send(PtpIpFrame(PtpIpPacket.initCommandRequest, payload));
    final ack = await _next(timeout);
    if (ack.type == PtpIpPacket.initFail) {
      final code = ack.payload.length >= 4 ? ByteData.sublistView(ack.payload).getUint32(0, Endian.little) : -1;
      throw PtpException('camera refused the connection (InitFail 0x${code.toRadixString(16)}) — '
          'it may need to be put back into wireless mode, or to accept this device on its screen');
    }
    if (ack.type != PtpIpPacket.initCommandAck) {
      throw PtpException('unexpected handshake reply: ${ack.type} (${_hex(ack.payload)})');
    }
    sessionId = ack.payload.length >= 4 ? ByteData.sublistView(ack.payload).getUint32(0, Endian.little) : 0;
    log?.call('InitCommandAck session=0x${sessionId.toRadixString(16)} ${_hex(ack.payload)}');
  }

  // ------------------------------------------------------------ framing

  void _send(PtpIpFrame f) {
    log?.call('→ $f ${_hex(f.payload)}');
    _socket.add(f.pack());
  }

  void _onBytes(Uint8List chunk) {
    _buffer.add(chunk);
    var bytes = _buffer.toBytes();
    var offset = 0;
    while (bytes.length - offset >= 8) {
      final len = ByteData.sublistView(bytes, offset).getUint32(0, Endian.little);
      if (len < 8 || len > 64 * 1024 * 1024) {
        _frames.addError(PtpException('bad PTP/IP frame length $len'));
        return;
      }
      if (bytes.length - offset < len) break;
      final type = ByteData.sublistView(bytes, offset).getUint32(4, Endian.little);
      final f = PtpIpFrame(type, Uint8List.sublistView(bytes, offset + 8, offset + len));
      log?.call('← $f');
      _frames.add(f);
      offset += len;
    }
    _buffer.clear();
    if (offset < bytes.length) _buffer.add(Uint8List.sublistView(bytes, offset));
  }

  void _onError(Object e) => _frames.addError(e);
  void _onDone() {
    if (!_frames.isClosed) _frames.close();
  }

  Future<PtpIpFrame> _next(Duration timeout) => _q.next.timeout(timeout,
      onTimeout: () => throw PtpException('camera stopped answering (waited ${timeout.inSeconds}s)'));

  // ------------------------------------------------------------ PtpSession

  @override
  void resetTransactionIds() => _txn = 0;
  int _nextTxn() => ++_txn;

  @override
  Future<PtpResult> sendCommand(int opcode, [List<int> params = const [], int timeoutMs = 5000]) =>
      _operation(opcode, params, null, timeoutMs);

  @override
  Future<PtpResult> sendDataCommand(int opcode, List<int> params, Uint8List data, [int timeoutMs = 5000]) =>
      _operation(opcode, params, data, timeoutMs);

  Future<PtpResult> _operation(int opcode, List<int> params, Uint8List? outData, int timeoutMs) async {
    final timeout = Duration(milliseconds: timeoutMs);
    final txn = _nextTxn();
    // dataPhaseInfo: 1 = no data or data-in, 2 = data-out
    final req = BytesBuilder()
      ..add(_u32(outData == null ? 1 : 2))
      ..add(_u16(opcode))
      ..add(_u32(txn));
    for (final p in params) {
      req.add(_u32(p));
    }
    _send(PtpIpFrame(PtpIpPacket.operationRequest, req.toBytes()));

    if (outData != null) {
      _send(PtpIpFrame(PtpIpPacket.startData, Uint8List.fromList([..._u32(txn), ..._u64(outData.length)])));
      _send(PtpIpFrame(PtpIpPacket.endData, Uint8List.fromList([..._u32(txn), ...outData])));
    }

    final inData = BytesBuilder();
    while (true) {
      final f = await _next(timeout);
      switch (f.type) {
        case PtpIpPacket.startData:
          break; // length header only
        case PtpIpPacket.data:
          inData.add(Uint8List.sublistView(f.payload, 4));
        case PtpIpPacket.endData:
          inData.add(Uint8List.sublistView(f.payload, 4));
        case PtpIpPacket.operationResponse:
          final bd = ByteData.sublistView(f.payload);
          final code = bd.getUint16(0, Endian.little);
          final out = <int>[];
          for (var o = 6; o + 4 <= f.payload.length; o += 4) {
            out.add(bd.getUint32(o, Endian.little));
          }
          return PtpResult(code, out, inData.toBytes());
        case PtpIpPacket.event:
          continue; // asynchronous, not ours to handle here
        default:
          throw PtpException('unexpected packet in transaction: ${PtpIpPacket.name(f.type)} ${_hex(f.payload)}');
      }
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    _socket.destroy();
    // StreamQueue leaves the subscription paused between requests, and closing a controller
    // with a paused listener never completes — cancel the queue first.
    await _q.cancel(immediate: true);
    if (!_frames.isClosed) unawaited(_frames.close());
  }

  // ------------------------------------------------------------ helpers

  static Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
  static Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
  static Uint8List _u64(int v) => Uint8List(8)..buffer.asByteData().setUint64(0, v, Endian.little);

  /// PTP/IP strings are UTF-16LE, null-terminated.
  static Uint8List _utf16z(String s) {
    final out = Uint8List((s.length + 1) * 2);
    final bd = ByteData.sublistView(out);
    for (var i = 0; i < s.length; i++) {
      bd.setUint16(i * 2, s.codeUnitAt(i), Endian.little);
    }
    return out;
  }

  static String _hex(Uint8List b) =>
      b.take(48).map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ') + (b.length > 48 ? ' …(${b.length}B)' : '');
}

/// Find Fuji bodies on the local network by probing the PTP/IP command port.
/// [subnet] is a /24 prefix such as `192.168.0`.
Future<List<String>> scanForCameras(String subnet, {Duration perHost = const Duration(milliseconds: 350)}) async {
  final found = <String>[];
  final probes = <Future<void>>[];
  for (var i = 1; i < 255; i++) {
    final host = '$subnet.$i';
    probes.add(() async {
      try {
        final s = await Socket.connect(host, FujiWifi.commandPort, timeout: perHost);
        found.add(host);
        s.destroy();
      } catch (_) {/* closed or unreachable */}
    }());
  }
  await Future.wait(probes);
  found.sort();
  return found;
}
