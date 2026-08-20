import 'dart:async';
import 'dart:typed_data';

import '../ptp/binary.dart';
import '../ptp/codes.dart';
import '../ptp/container.dart';
import '../ptp/transport.dart';

/// Scripted Fujifilm body: answers PTP over a fake UsbLink. Models slots, props, session state.
class FakeFujiBody implements UsbLink {
  FakeFujiBody({
    this.model = 'X-S20',
    this.firmware = '3.30',
    this.slotCount = 4,
    Set<int>? supported,
    this.staleSessionOnce = false,
  }) : supported = supported ?? {0xD212, 0xD185, 0xD183, for (var p = 0xD18C; p <= 0xD1A5; p++) if (p != 0xD198) p} {
    for (var s = 1; s <= slotCount; s++) {
      slots[s] = {
        0xD18D: packPtpString(''),
        for (var p = 0xD18E; p <= 0xD1A5; p++)
          if (this.supported.contains(p)) p: Uint8List.fromList([0, 0]),
      };
      slots[s]![0xD192] = Uint8List.fromList([1, 0]);
      slots[s]![0xD190] = Uint8List.fromList([100, 0]);
      slots[s]![0xD195] = Uint8List.fromList([1, 0]);
      slots[s]![0xD199] = Uint8List.fromList([2, 0]);
      slots[s]![0xD1A1] = Uint8List.fromList([0x00, 0x20]);
      slots[s]![0xD18E] = Uint8List.fromList([7, 0]);
      slots[s]![0xD1A5] = Uint8List.fromList([7, 0]);
    }
  }

  final String model, firmware;
  final int slotCount;
  final Set<int> supported;
  bool staleSessionOnce;
  bool sessionOpen = false;
  int currentSlot = 1;
  final Map<int, Map<int, Uint8List>> slots = {};
  final List<String> log = [];

  /// Props the body rejects on write (simulates read-only / conditional props).
  final Set<int> rejectWrites = {};

  /// Reject a write with a specific PTP response — a body that has the property but has it
  /// locked (HDR on, say) answers differently from one that never had it.
  final Map<int, int> rejectWritesWith = {};

  /// When set, 0xD18D writes longer than this respond InvalidDevicePropValue (0 = no names at all).
  int? nameMaxLen;

  /// Body accepts the 0xD18D write but keeps an empty name (observed on X-S20).
  bool dropNameOnWrite = false;

  /// Props where the written value silently differs on read-back.
  final Set<int> corruptOnWrite = {};

  final List<Uint8List> _outQueue = [];
  PtpContainer? _pendingCmd;

  // ------------------------------------------------------------ UsbLink
  @override
  Future<int> bulkOut(Uint8List data, {int timeoutMs = 5000}) async {
    final c = PtpContainer.unpack(data);
    if (c.type == ContainerType.command) {
      _pendingCmd = c;
      if (!_needsDataPhase(c.code)) _handle(c, null);
    } else if (c.type == ContainerType.data) {
      _handle(_pendingCmd!, c.data);
      _pendingCmd = null;
    }
    return data.length;
  }

  @override
  Future<Uint8List> bulkIn(int maxLen, {int timeoutMs = 5000}) async {
    if (_outQueue.isEmpty) throw StateError('fake body: nothing to read');
    final b = _outQueue.removeAt(0);
    if (b.length <= maxLen) return b;
    _outQueue.insert(0, b.sublist(maxLen));
    return b.sublist(0, maxLen);
  }

  bool _needsDataPhase(int op) => op == Op.setDevicePropValue;

  void _resp(PtpContainer cmd, int code) =>
      _outQueue.add(PtpContainer(type: ContainerType.response, code: code, transactionId: cmd.transactionId).pack());
  void _data(PtpContainer cmd, Uint8List d) =>
      _outQueue.add(PtpContainer(type: ContainerType.data, code: cmd.code, transactionId: cmd.transactionId, data: d).pack());

  void _handle(PtpContainer cmd, Uint8List? data) {
    log.add('${cmd.code.toRadixString(16)} ${cmd.params}');
    switch (cmd.code) {
      case Op.openSession:
        if (sessionOpen || staleSessionOnce) {
          staleSessionOnce = false;
          sessionOpen = true; // the stale session is "open" from the body's view
          _resp(cmd, Resp.sessionAlreadyOpen);
        } else {
          sessionOpen = true;
          _resp(cmd, Resp.ok);
        }
      case Op.closeSession:
        sessionOpen = false;
        _resp(cmd, Resp.ok);
      case Op.getDeviceInfo:
        _data(cmd, _deviceInfo());
        _resp(cmd, Resp.ok);
      case Op.getDevicePropValue:
        final prop = cmd.params[0];
        if (!supported.contains(prop)) {
          _resp(cmd, Resp.devicePropNotSupported);
        } else if (prop == 0xD18C) {
          _data(cmd, Uint8List.fromList([currentSlot, 0]));
          _resp(cmd, Resp.ok);
        } else if (prop == 0xD212) {
          _data(cmd, Uint8List.fromList([1, 0]));
          _resp(cmd, Resp.ok);
        } else {
          _data(cmd, slots[currentSlot]![prop] ?? Uint8List.fromList([0, 0]));
          _resp(cmd, Resp.ok);
        }
      case Op.setDevicePropValue:
        final prop = cmd.params[0];
        if (rejectWritesWith.containsKey(prop)) {
          _resp(cmd, rejectWritesWith[prop]!);
        } else if (!supported.contains(prop) || rejectWrites.contains(prop)) {
          _resp(cmd, Resp.devicePropNotSupported);
        } else if (prop == 0xD18D && nameMaxLen != null && ByteReader(Uint8List.fromList(data!)).ptpString().length > nameMaxLen!) {
          _resp(cmd, Resp.invalidDevicePropValue);
        } else if (prop == 0xD18D && dropNameOnWrite) {
          slots[currentSlot]![prop] = packPtpString('');
          _resp(cmd, Resp.ok);
        } else if (prop == 0xD18C) {
          final s = data![0];
          if (s < 1 || s > slotCount) {
            _resp(cmd, Resp.devicePropNotSupported);
          } else {
            currentSlot = s;
            _resp(cmd, Resp.ok);
          }
        } else {
          var v = Uint8List.fromList(data!);
          if (corruptOnWrite.contains(prop)) v = Uint8List.fromList([v[0] ^ 0xFF, v.length > 1 ? v[1] : 0]);
          slots[currentSlot]![prop] = v;
          _resp(cmd, Resp.ok);
        }
      default:
        _resp(cmd, Resp.operationNotSupported);
    }
  }

  Uint8List _deviceInfo() {
    final w = ByteWriter()
      ..u16(100)
      ..u32(0x6)
      ..u16(100)
      ..ptpString('fujifilm.co.jp: 1.0; ')
      ..u16(0)
      ..u16Array([Op.getDeviceInfo, Op.openSession, Op.closeSession, Op.getDevicePropValue, Op.setDevicePropValue])
      ..u16Array([])
      ..u16Array(supported.toList()..sort())
      ..u16Array([0x3801])
      ..u16Array([0x3801])
      ..ptpString('FUJIFILM')
      ..ptpString(model)
      ..ptpString(firmware)
      ..ptpString('SERIAL');
    return w.toBytes();
  }
}
