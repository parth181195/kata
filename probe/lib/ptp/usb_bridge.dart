import 'package:flutter/services.dart';

import 'transport.dart';

class UsbInterfaceInfo {
  UsbInterfaceInfo(this.id, this.cls, this.sub, this.proto, this.bulkIn, this.bulkOut);
  final int id, cls, sub, proto;
  final int? bulkIn, bulkOut;
  bool get hasBulkPair => bulkIn != null && bulkOut != null;
  @override
  String toString() =>
      'if#$id class=$cls/$sub/$proto bulkIn=${bulkIn?.toRadixString(16) ?? '-'} bulkOut=${bulkOut?.toRadixString(16) ?? '-'}';
}

class UsbDeviceInfo {
  UsbDeviceInfo({
    required this.name,
    required this.vid,
    required this.pid,
    required this.product,
    required this.manufacturer,
    required this.hasPermission,
    required this.interfaces,
  });
  final String name;
  final int vid, pid;
  final String? product, manufacturer;
  final bool hasPermission;
  final List<UsbInterfaceInfo> interfaces;

  static UsbDeviceInfo fromMap(Map m) => UsbDeviceInfo(
        name: m['name'] as String,
        vid: m['vid'] as int,
        pid: m['pid'] as int,
        product: m['product'] as String?,
        manufacturer: m['manufacturer'] as String?,
        hasPermission: m['hasPermission'] as bool,
        interfaces: (m['interfaces'] as List)
            .map((e) => UsbInterfaceInfo(e['id'] as int, e['cls'] as int, e['sub'] as int, e['proto'] as int,
                e['bulkIn'] as int?, e['bulkOut'] as int?))
            .toList(),
      );

  String get idString =>
      '${vid.toRadixString(16).padLeft(4, '0')}:${pid.toRadixString(16).padLeft(4, '0')}';
}

/// Dart side of the Kotlin `fuji/usb` MethodChannel. Implements [UsbLink].
class UsbBridge implements UsbLink {
  static const _ch = MethodChannel('fuji/usb');

  Future<List<UsbDeviceInfo>> listDevices() async {
    final r = await _ch.invokeMethod<List>('listDevices');
    return (r ?? []).map((e) => UsbDeviceInfo.fromMap(e as Map)).toList();
  }

  Future<bool> requestPermission(String name) async =>
      (await _ch.invokeMethod<bool>('requestPermission', {'name': name})) ?? false;

  Future<Map> open(String name, {int? interfaceId}) async =>
      (await _ch.invokeMethod<Map>('open', {'name': name, 'interfaceId': interfaceId}))!;

  Future<void> close() => _ch.invokeMethod('close');

  @override
  Future<int> bulkOut(Uint8List data, {int timeoutMs = 5000}) async =>
      (await _ch.invokeMethod<int>('bulkOut', {'data': data, 'timeoutMs': timeoutMs})) ?? 0;

  @override
  Future<Uint8List> bulkIn(int maxLen, {int timeoutMs = 5000}) async =>
      (await _ch.invokeMethod<Uint8List>('bulkIn', {'maxLen': maxLen, 'timeoutMs': timeoutMs})) ?? Uint8List(0);
}
