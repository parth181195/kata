import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_probe/ptp/binary.dart';
import 'package:fuji_probe/ptp/codes.dart';
import 'package:fuji_probe/ptp/container.dart';
import 'package:fuji_probe/ptp/device_info.dart';
import 'package:fuji_probe/ptp/transport.dart';

Uint8List bytes(List<int> l) => Uint8List.fromList(l);

void main() {
  group('binary', () {
    test('u16/u32 LE round trip', () {
      final w = ByteWriter()
        ..u16(0xD192)
        ..u32(0xDEADBEEF)
        ..i16(-5);
      expect(w.toBytes(), bytes([0x92, 0xD1, 0xEF, 0xBE, 0xAD, 0xDE, 0xFB, 0xFF]));
      final r = ByteReader(w.toBytes());
      expect(r.u16(), 0xD192);
      expect(r.u32(), 0xDEADBEEF);
      expect(r.i16(), -5);
    });

    test('PTP string encode: "Kodachrome 64" -> len byte + UCS-2LE + NUL', () {
      final b = packPtpString('Kodachrome 64');
      expect(b.length, 1 + 14 * 2);
      expect(b[0], 14); // 13 chars + terminator
      expect(b[1], 'K'.codeUnitAt(0));
      expect(b[2], 0);
      expect(b[b.length - 2], 0);
      expect(b[b.length - 1], 0);
    });

    test('PTP string decode', () {
      final b = packPtpString('X-S20');
      expect(ByteReader(b).ptpString(), 'X-S20');
      expect(ByteReader(bytes([0])).ptpString(), '');
    });

    test('u16 array', () {
      final r = ByteReader(bytes([2, 0, 0, 0, 0x01, 0x10, 0x8C, 0xD1]));
      expect(r.u16Array(), [0x1001, 0xD18C]);
    });
  });

  group('container', () {
    test('pack command with one param', () {
      final c = PtpContainer(
        type: ContainerType.command,
        code: Op.setDevicePropValue,
        transactionId: 42,
        params: [0xD192],
      );
      expect(
        c.pack(),
        bytes([
          0x10, 0, 0, 0, // len 16
          0x01, 0x00, // CMD
          0x16, 0x10, // 0x1016
          0x2A, 0, 0, 0, // txn 42
          0x92, 0xD1, 0, 0, // param
        ]),
      );
    });

    test('pack data container with payload u16=11', () {
      final c = PtpContainer(
        type: ContainerType.data,
        code: Op.setDevicePropValue,
        transactionId: 42,
        data: bytes([0x0B, 0x00]),
      );
      expect(c.pack(), bytes([0x0E, 0, 0, 0, 0x02, 0, 0x16, 0x10, 0x2A, 0, 0, 0, 0x0B, 0x00]));
    });

    test('unpack response', () {
      final c = PtpContainer.unpack(bytes([0x0C, 0, 0, 0, 0x03, 0, 0x01, 0x20, 0x2A, 0, 0, 0]));
      expect(c.type, ContainerType.response);
      expect(c.code, Resp.ok);
      expect(c.transactionId, 42);
      expect(c.params, isEmpty);
      expect(c.data, isEmpty);
    });

    test('unpack response with params', () {
      final c = PtpContainer.unpack(bytes([0x14, 0, 0, 0, 0x03, 0, 0x01, 0x20, 1, 0, 0, 0, 7, 0, 0, 0, 8, 0, 0, 0]));
      expect(c.params, [7, 8]);
    });

    test('declaredLength reads header', () {
      expect(PtpContainer.declaredLength(bytes([0x10, 0x02, 0, 0, 2, 0])), 0x210);
    });
  });

  group('device info', () {
    test('parses a synthetic Fuji DeviceInfo', () {
      final w = ByteWriter()
        ..u16(100) // standard version
        ..u32(0xE) // vendor ext id
        ..u16(1) // vendor ext version
        ..ptpString('fujifilm.co.jp: 1.0;')
        ..u16(0) // functional mode
        ..u16Array([0x1001, 0x1002, 0x1015, 0x1016])
        ..u16Array([0xC004])
        ..u16Array([0xD18C, 0xD18D, 0xD192, 0x5005])
        ..u16Array([0x3801])
        ..u16Array([0x3801, 0xB103])
        ..ptpString('FUJIFILM')
        ..ptpString('X-S20')
        ..ptpString('1.20')
        ..ptpString('1234567890');
      final d = DeviceInfo.parse(w.toBytes());
      expect(d.vendorExtensionId, 0xE);
      expect(d.manufacturer, 'FUJIFILM');
      expect(d.model, 'X-S20');
      expect(d.deviceVersion, '1.20');
      expect(d.serialNumber, '1234567890');
      expect(d.operations, contains(0x1016));
      expect(d.properties, containsAll([0xD18C, 0xD192]));
      expect(d.supportsProp(0xD18C), isTrue);
      expect(d.supportsProp(0xD1A5), isFalse);
    });
  });

  group('transport', () {
    test('sendCommand: CMD out, DATA+RESP in', () async {
      final link = FakeLink();
      // camera answers GetDevicePropValue(D192) with DATA(u16=11) then RESP OK
      link.queueIn(PtpContainer(type: ContainerType.data, code: Op.getDevicePropValue, transactionId: 1, data: bytes([11, 0])).pack());
      link.queueIn(PtpContainer(type: ContainerType.response, code: Resp.ok, transactionId: 1).pack());
      final t = PtpTransport(link);
      final r = await t.sendCommand(Op.getDevicePropValue, [0xD192]);
      expect(r.code, Resp.ok);
      expect(r.data, bytes([11, 0]));
      expect(link.outs.length, 1);
      expect(link.outs.first.sublist(4, 8), bytes([1, 0, 0x15, 0x10]));
    });

    test('sendDataCommand: CMD+DATA out, RESP in, txn ids match', () async {
      final link = FakeLink();
      link.queueIn(PtpContainer(type: ContainerType.response, code: Resp.ok, transactionId: 1).pack());
      final t = PtpTransport(link);
      final r = await t.sendDataCommand(Op.setDevicePropValue, [0xD192], bytes([11, 0]));
      expect(r.code, Resp.ok);
      expect(link.outs.length, 2);
      final cmd = PtpContainer.unpack(link.outs[0]);
      final dat = PtpContainer.unpack(link.outs[1]);
      expect(cmd.type, ContainerType.command);
      expect(dat.type, ContainerType.data);
      expect(cmd.transactionId, dat.transactionId);
      expect(dat.data, bytes([11, 0]));
    });

    test('recv reassembles a container split across two bulk reads', () async {
      final link = FakeLink();
      final big = PtpContainer(type: ContainerType.data, code: Op.getDevicePropValue, transactionId: 1, data: Uint8List(40000)).pack();
      link.queueIn(big.sublist(0, 16384));
      link.queueIn(big.sublist(16384));
      link.queueIn(PtpContainer(type: ContainerType.response, code: Resp.ok, transactionId: 1).pack());
      final t = PtpTransport(link);
      final r = await t.sendCommand(Op.getDevicePropValue, [0xD185]);
      expect(r.data.length, 40000);
    });
  });
}

class FakeLink implements UsbLink {
  final List<Uint8List> outs = [];
  final List<Uint8List> ins = [];
  void queueIn(Uint8List b) => ins.add(b);

  @override
  Future<int> bulkOut(Uint8List data, {int timeoutMs = 5000}) async {
    outs.add(Uint8List.fromList(data));
    return data.length;
  }

  @override
  Future<Uint8List> bulkIn(int maxLen, {int timeoutMs = 5000}) async {
    if (ins.isEmpty) throw StateError('no more data');
    final b = ins.removeAt(0);
    if (b.length <= maxLen) return b;
    ins.insert(0, b.sublist(maxLen));
    return b.sublist(0, maxLen);
  }
}
