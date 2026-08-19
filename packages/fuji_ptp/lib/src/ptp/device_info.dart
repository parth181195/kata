import 'dart:typed_data';

import 'binary.dart';

/// Parsed PTP DeviceInfo dataset (ISO 15740 §5.1.1).
class DeviceInfo {
  DeviceInfo({
    required this.standardVersion,
    required this.vendorExtensionId,
    required this.vendorExtensionVersion,
    required this.vendorExtensionDesc,
    required this.functionalMode,
    required this.operations,
    required this.events,
    required this.properties,
    required this.captureFormats,
    required this.imageFormats,
    required this.manufacturer,
    required this.model,
    required this.deviceVersion,
    required this.serialNumber,
  });

  final int standardVersion;
  final int vendorExtensionId;
  final int vendorExtensionVersion;
  final String vendorExtensionDesc;
  final int functionalMode;
  final List<int> operations;
  final List<int> events;
  final List<int> properties;
  final List<int> captureFormats;
  final List<int> imageFormats;
  final String manufacturer;
  final String model;
  final String deviceVersion;
  final String serialNumber;

  late final Set<int> _props = properties.toSet();
  late final Set<int> _ops = operations.toSet();

  bool supportsProp(int code) => _props.contains(code);
  bool supportsOp(int code) => _ops.contains(code);

  static DeviceInfo parse(Uint8List data) {
    final r = ByteReader(data);
    final standardVersion = r.u16();
    final vendorExtId = r.u32();
    final vendorExtVer = r.u16();
    final vendorExtDesc = r.ptpString();
    final functionalMode = r.u16();
    final ops = r.u16Array();
    final events = r.u16Array();
    final props = r.u16Array();
    final capFmts = r.u16Array();
    final imgFmts = r.u16Array();
    final manufacturer = r.ptpString();
    final model = r.ptpString();
    final version = r.ptpString();
    final serial = r.ptpString();
    return DeviceInfo(
      standardVersion: standardVersion,
      vendorExtensionId: vendorExtId,
      vendorExtensionVersion: vendorExtVer,
      vendorExtensionDesc: vendorExtDesc,
      functionalMode: functionalMode,
      operations: ops,
      events: events,
      properties: props,
      captureFormats: capFmts,
      imageFormats: imgFmts,
      manufacturer: manufacturer,
      model: model,
      deviceVersion: version,
      serialNumber: serial,
    );
  }
}
