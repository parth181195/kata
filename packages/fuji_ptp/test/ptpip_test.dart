@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

/// A scripted PTP/IP camera: speaks the framing back at us so we can prove the client
/// builds correct packets and reassembles split data phases.
class FakePtpIpCamera {
  FakePtpIpCamera._(this._server);
  final ServerSocket _server;
  final frames = <PtpIpFrame>[];
  bool refuse = false;

  int get port => _server.port;

  static Future<FakePtpIpCamera> start() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cam = FakePtpIpCamera._(s);
    s.listen(cam._serve);
    return cam;
  }

  void _serve(Socket sock) {
    final buf = BytesBuilder(copy: false);
    sock.listen((chunk) {
      buf.add(chunk);
      var bytes = buf.toBytes();
      var off = 0;
      while (bytes.length - off >= 8) {
        final len = ByteData.sublistView(bytes, off).getUint32(0, Endian.little);
        if (bytes.length - off < len) break;
        final type = ByteData.sublistView(bytes, off).getUint32(4, Endian.little);
        final f = PtpIpFrame(type, Uint8List.sublistView(bytes, off + 8, off + len));
        frames.add(f);
        _reply(sock, f);
        off += len;
      }
      buf.clear();
      if (off < bytes.length) buf.add(Uint8List.sublistView(bytes, off));
    });
  }

  void _reply(Socket sock, PtpIpFrame f) {
    Uint8List u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
    switch (f.type) {
      case PtpIpPacket.initCommandRequest:
        if (refuse) {
          sock.add(PtpIpFrame(PtpIpPacket.initFail, u32(0x2003)).pack());
          return;
        }
        // session id + our own guid/name echo (the client only reads the session id)
        sock.add(PtpIpFrame(PtpIpPacket.initCommandAck, Uint8List.fromList([...u32(0xABCD), ...List.filled(16, 0)])).pack());
      case PtpIpPacket.operationRequest:
        final bd = ByteData.sublistView(f.payload);
        final op = bd.getUint16(4, Endian.little);
        final txn = bd.getUint32(6, Endian.little);
        if (op == Op.getDeviceInfo) {
          // split the data phase across Data + EndData to exercise reassembly
          final payload = Uint8List.fromList(List.generate(300, (i) => i % 256));
          sock.add(PtpIpFrame(PtpIpPacket.startData, Uint8List.fromList([...u32(txn), ...Uint8List(8)])).pack());
          sock.add(PtpIpFrame(PtpIpPacket.data, Uint8List.fromList([...u32(txn), ...payload.sublist(0, 100)])).pack());
          sock.add(PtpIpFrame(PtpIpPacket.endData, Uint8List.fromList([...u32(txn), ...payload.sublist(100)])).pack());
        }
        sock.add(PtpIpFrame(PtpIpPacket.operationResponse, Uint8List.fromList([0x01, 0x20, ...u32(txn), ...u32(7)])).pack());
      default:
        break;
    }
  }

  Future<void> stop() => _server.close();
}

void main() {
  test('handshake sends a well-formed InitCommandRequest and keeps the session id', () async {
    final cam = await FakePtpIpCamera.start();
    final t = await PtpIpTransport.connect('127.0.0.1', port: cam.port, clientName: 'Kata');
    expect(t.sessionId, 0xABCD);

    final init = cam.frames.single;
    expect(init.type, PtpIpPacket.initCommandRequest);
    // 16-byte GUID, then UTF-16LE "Kata\0", then the 4-byte protocol version
    expect(init.payload.length, 16 + 10 + 4);
    expect(init.payload.sublist(0, 4), [0x4B, 0x41, 0x54, 0x41]);
    // "Kata" as UTF-16LE, then the terminator
    expect(Uint8List.sublistView(init.payload, 16, 26), [0x4B, 0, 0x61, 0, 0x74, 0, 0x61, 0, 0, 0]);
    expect(ByteData.sublistView(init.payload).getUint32(26, Endian.little), 0x00010000);
    await t.close();
    await cam.stop();
  });

  test('a data-in command reassembles Data + EndData and returns the response code', () async {
    final cam = await FakePtpIpCamera.start();
    final t = await PtpIpTransport.connect('127.0.0.1', port: cam.port);
    final r = await t.sendCommand(Op.getDeviceInfo);
    expect(r.ok, isTrue);
    expect(r.data.length, 300);
    expect(r.data[0], 0);
    expect(r.data[299], 299 % 256);
    expect(r.params, [7]);
    await t.close();
    await cam.stop();
  });

  test('a data-out command frames StartData + EndData with the payload', () async {
    final cam = await FakePtpIpCamera.start();
    final t = await PtpIpTransport.connect('127.0.0.1', port: cam.port);
    final r = await t.sendDataCommand(Op.setDevicePropValue, [0xD18D], Uint8List.fromList([1, 2, 3, 4]));
    expect(r.ok, isTrue);
    final sent = cam.frames.map((f) => f.type).toList();
    expect(sent, containsAllInOrder([PtpIpPacket.operationRequest, PtpIpPacket.startData, PtpIpPacket.endData]));
    final req = cam.frames.firstWhere((f) => f.type == PtpIpPacket.operationRequest);
    expect(ByteData.sublistView(req.payload).getUint32(0, Endian.little), 2, reason: 'data-out phase flag');
    expect(ByteData.sublistView(req.payload).getUint16(4, Endian.little), Op.setDevicePropValue);
    final end = cam.frames.firstWhere((f) => f.type == PtpIpPacket.endData);
    expect(Uint8List.sublistView(end.payload, 4), [1, 2, 3, 4]);
    await t.close();
    await cam.stop();
  });

  test('a refused handshake explains itself instead of hanging', () async {
    final cam = await FakePtpIpCamera.start()..refuse = true;
    await expectLater(
      PtpIpTransport.connect('127.0.0.1', port: cam.port),
      throwsA(isA<PtpException>().having((e) => e.message, 'message', contains('refused'))),
    );
    await cam.stop();
  });

  test('transaction ids increment and reset', () async {
    final cam = await FakePtpIpCamera.start();
    final t = await PtpIpTransport.connect('127.0.0.1', port: cam.port);
    await t.sendCommand(Op.openSession, [1]);
    await t.sendCommand(Op.getDeviceInfo);
    final txns = cam.frames
        .where((f) => f.type == PtpIpPacket.operationRequest)
        .map((f) => ByteData.sublistView(f.payload).getUint32(6, Endian.little))
        .toList();
    expect(txns, [1, 2]);
    t.resetTransactionIds();
    await t.sendCommand(Op.getDeviceInfo);
    final again = cam.frames
        .where((f) => f.type == PtpIpPacket.operationRequest)
        .map((f) => ByteData.sublistView(f.payload).getUint32(6, Endian.little))
        .toList();
    expect(again.last, 1);
    await t.close();
    await cam.stop();
  });
}
