// Desktop USB transport: libusb-1.0 over dart:ffi, behind the same [UsbHost]/[UsbLink]
// surface the Android bridge implements. All libusb calls run on a dedicated worker
// isolate (bulk transfers block), commands are marshalled over SendPorts.
//
// Linux: after the udev rule below, no root needed. macOS: works out of the box for
// PTP-class devices. Windows: requires the WinUSB driver on the camera interface.
//
//   /etc/udev/rules.d/71-fujifilm.rules
//   SUBSYSTEM=="usb", ATTR{idVendor}=="04cb", MODE="0666", TAG+="uaccess"
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'transport.dart';
import 'usb_bridge.dart';

// ---------------------------------------------------------------- FFI decls

final class _DeviceDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint16()
  external int bcdUSB;
  @Uint8()
  external int bDeviceClass;
  @Uint8()
  external int bDeviceSubClass;
  @Uint8()
  external int bDeviceProtocol;
  @Uint8()
  external int bMaxPacketSize0;
  @Uint16()
  external int idVendor;
  @Uint16()
  external int idProduct;
  @Uint16()
  external int bcdDevice;
  @Uint8()
  external int iManufacturer;
  @Uint8()
  external int iProduct;
  @Uint8()
  external int iSerialNumber;
  @Uint8()
  external int bNumConfigurations;
}

final class _EndpointDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint8()
  external int bEndpointAddress;
  @Uint8()
  external int bmAttributes;
  @Uint16()
  external int wMaxPacketSize;
  @Uint8()
  external int bInterval;
  @Uint8()
  external int bRefresh;
  @Uint8()
  external int bSynchAddress;
  external Pointer<Uint8> extra;
  @Int32()
  external int extraLength;
}

final class _InterfaceDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint8()
  external int bInterfaceNumber;
  @Uint8()
  external int bAlternateSetting;
  @Uint8()
  external int bNumEndpoints;
  @Uint8()
  external int bInterfaceClass;
  @Uint8()
  external int bInterfaceSubClass;
  @Uint8()
  external int bInterfaceProtocol;
  @Uint8()
  external int iInterface;
  external Pointer<_EndpointDescriptor> endpoint;
  external Pointer<Uint8> extra;
  @Int32()
  external int extraLength;
}

final class _Interface extends Struct {
  external Pointer<_InterfaceDescriptor> altsetting;
  @Int32()
  external int numAltsetting;
}

final class _ConfigDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint16()
  external int wTotalLength;
  @Uint8()
  external int bNumInterfaces;
  @Uint8()
  external int bConfigurationValue;
  @Uint8()
  external int iConfiguration;
  @Uint8()
  external int bmAttributes;
  @Uint8()
  external int maxPower;
  external Pointer<_Interface> interface;
  external Pointer<Uint8> extra;
  @Int32()
  external int extraLength;
}

class _Libusb {
  _Libusb(DynamicLibrary lib)
      : init = lib.lookupFunction<Int32 Function(Pointer<Pointer<Void>>), int Function(Pointer<Pointer<Void>>)>('libusb_init'),
        exit_ = lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('libusb_exit'),
        getDeviceList = lib.lookupFunction<IntPtr Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>), int Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>)>('libusb_get_device_list'),
        freeDeviceList = lib.lookupFunction<Void Function(Pointer<Pointer<Void>>, Int32), void Function(Pointer<Pointer<Void>>, int)>('libusb_free_device_list'),
        getDeviceDescriptor = lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<_DeviceDescriptor>), int Function(Pointer<Void>, Pointer<_DeviceDescriptor>)>('libusb_get_device_descriptor'),
        getBusNumber = lib.lookupFunction<Uint8 Function(Pointer<Void>), int Function(Pointer<Void>)>('libusb_get_bus_number'),
        getDeviceAddress = lib.lookupFunction<Uint8 Function(Pointer<Void>), int Function(Pointer<Void>)>('libusb_get_device_address'),
        open = lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>), int Function(Pointer<Void>, Pointer<Pointer<Void>>)>('libusb_open'),
        close = lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('libusb_close'),
        getActiveConfig = lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Pointer<_ConfigDescriptor>>), int Function(Pointer<Void>, Pointer<Pointer<_ConfigDescriptor>>)>('libusb_get_active_config_descriptor'),
        freeConfig = lib.lookupFunction<Void Function(Pointer<_ConfigDescriptor>), void Function(Pointer<_ConfigDescriptor>)>('libusb_free_config_descriptor'),
        setAutoDetach = lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('libusb_set_auto_detach_kernel_driver'),
        claimInterface = lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('libusb_claim_interface'),
        releaseInterface = lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('libusb_release_interface'),
        bulkTransfer = lib.lookupFunction<Int32 Function(Pointer<Void>, Uint8, Pointer<Uint8>, Int32, Pointer<Int32>, Uint32), int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Int32>, int)>('libusb_bulk_transfer'),
        getStringAscii = lib.lookupFunction<Int32 Function(Pointer<Void>, Uint8, Pointer<Uint8>, Int32), int Function(Pointer<Void>, int, Pointer<Uint8>, int)>('libusb_get_string_descriptor_ascii');

  final int Function(Pointer<Pointer<Void>>) init;
  final void Function(Pointer<Void>) exit_;
  final int Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>) getDeviceList;
  final void Function(Pointer<Pointer<Void>>, int) freeDeviceList;
  final int Function(Pointer<Void>, Pointer<_DeviceDescriptor>) getDeviceDescriptor;
  final int Function(Pointer<Void>) getBusNumber;
  final int Function(Pointer<Void>) getDeviceAddress;
  final int Function(Pointer<Void>, Pointer<Pointer<Void>>) open;
  final void Function(Pointer<Void>) close;
  final int Function(Pointer<Void>, Pointer<Pointer<_ConfigDescriptor>>) getActiveConfig;
  final void Function(Pointer<_ConfigDescriptor>) freeConfig;
  final int Function(Pointer<Void>, int) setAutoDetach;
  final int Function(Pointer<Void>, int) claimInterface;
  final int Function(Pointer<Void>, int) releaseInterface;
  final int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Int32>, int) bulkTransfer;
  final int Function(Pointer<Void>, int, Pointer<Uint8>, int) getStringAscii;

  static DynamicLibrary load() {
    if (Platform.isMacOS) return DynamicLibrary.open('libusb-1.0.0.dylib');
    if (Platform.isWindows) return DynamicLibrary.open('libusb-1.0.dll');
    return DynamicLibrary.open('libusb-1.0.so.0');
  }
}

const _errAccess = -3;

// ---------------------------------------------------------------- worker isolate

class _Cmd {
  _Cmd(this.op, this.reply, [this.args = const {}]);
  final String op;
  final SendPort reply;
  final Map<String, Object?> args;
}

void _worker(SendPort ready) {
  final usb = _Libusb(_Libusb.load());
  final ctxOut = calloc<Pointer<Void>>();
  final rc = usb.init(ctxOut);
  final ctx = rc == 0 ? ctxOut.value : nullptr;
  calloc.free(ctxOut);

  Pointer<Void> handle = nullptr;
  var claimed = -1;
  var epIn = 0, epOut = 0;

  List<Map<String, Object?>> list({int? vidFilter}) {
    final out = <Map<String, Object?>>[];
    final listOut = calloc<Pointer<Pointer<Void>>>();
    final n = usb.getDeviceList(ctx, listOut);
    final devs = listOut.value;
    final desc = calloc<_DeviceDescriptor>();
    for (var i = 0; i < n; i++) {
      final dev = (devs + i).value;
      if (usb.getDeviceDescriptor(dev, desc) != 0) continue;
      final d = desc.ref;
      if (vidFilter != null && d.idVendor != vidFilter) continue;
      final name = '${usb.getBusNumber(dev)}:${usb.getDeviceAddress(dev)}';
      // interfaces + strings need an open; tolerate failure (permission)
      final interfaces = <Map<String, Object?>>[];
      String? product, manufacturer;
      var hasPermission = false;
      final hOut = calloc<Pointer<Void>>();
      if (usb.open(dev, hOut) == 0) {
        hasPermission = true;
        final h = hOut.value;
        final buf = calloc<Uint8>(256);
        if (d.iProduct != 0 && usb.getStringAscii(h, d.iProduct, buf, 256) > 0) {
          product = buf.cast<Utf8>().toDartString();
        }
        if (d.iManufacturer != 0 && usb.getStringAscii(h, d.iManufacturer, buf, 256) > 0) {
          manufacturer = buf.cast<Utf8>().toDartString();
        }
        calloc.free(buf);
        usb.close(h);
      }
      calloc.free(hOut);
      final cfgOut = calloc<Pointer<_ConfigDescriptor>>();
      if (usb.getActiveConfig(dev, cfgOut) == 0) {
        final cfg = cfgOut.value.ref;
        for (var ii = 0; ii < cfg.bNumInterfaces; ii++) {
          final iface = (cfg.interface + ii).ref;
          if (iface.numAltsetting < 1) continue;
          final alt = iface.altsetting.ref;
          int? bulkIn, bulkOut;
          for (var e = 0; e < alt.bNumEndpoints; e++) {
            final ep = (alt.endpoint + e).ref;
            if ((ep.bmAttributes & 0x03) != 0x02) continue; // bulk only
            if (ep.bEndpointAddress & 0x80 != 0) {
              bulkIn ??= ep.bEndpointAddress;
            } else {
              bulkOut ??= ep.bEndpointAddress;
            }
          }
          interfaces.add({
            'id': alt.bInterfaceNumber,
            'cls': alt.bInterfaceClass,
            'sub': alt.bInterfaceSubClass,
            'proto': alt.bInterfaceProtocol,
            'bulkIn': bulkIn,
            'bulkOut': bulkOut,
          });
        }
        usb.freeConfig(cfgOut.value);
      }
      calloc.free(cfgOut);
      out.add({
        'name': name,
        'vid': d.idVendor,
        'pid': d.idProduct,
        'product': product,
        'manufacturer': manufacturer,
        'hasPermission': hasPermission,
        'interfaces': interfaces,
      });
    }
    calloc.free(desc);
    if (n >= 0) usb.freeDeviceList(devs, 1);
    calloc.free(listOut);
    return out;
  }

  Map<String, Object?> openDevice(String name, int? interfaceId) {
    final listOut = calloc<Pointer<Pointer<Void>>>();
    final n = usb.getDeviceList(ctx, listOut);
    final devs = listOut.value;
    try {
      for (var i = 0; i < n; i++) {
        final dev = (devs + i).value;
        if ('${usb.getBusNumber(dev)}:${usb.getDeviceAddress(dev)}' != name) continue;
        final hOut = calloc<Pointer<Void>>();
        final rc = usb.open(dev, hOut);
        if (rc != 0) {
          calloc.free(hOut);
          return {'error': rc == _errAccess ? 'permission' : 'open failed ($rc)'};
        }
        handle = hOut.value;
        calloc.free(hOut);
        usb.setAutoDetach(handle, 1);
        // pick the interface: requested id, else first with a bulk pair (PTP = class 6)
        final cfgOut = calloc<Pointer<_ConfigDescriptor>>();
        if (usb.getActiveConfig(dev, cfgOut) != 0) return {'error': 'no config'};
        final cfg = cfgOut.value.ref;
        Map<String, int>? pick;
        for (var ii = 0; ii < cfg.bNumInterfaces; ii++) {
          final alt = (cfg.interface + ii).ref.altsetting.ref;
          int? bIn, bOut;
          for (var e = 0; e < alt.bNumEndpoints; e++) {
            final ep = (alt.endpoint + e).ref;
            if ((ep.bmAttributes & 0x03) != 0x02) continue;
            if (ep.bEndpointAddress & 0x80 != 0) {
              bIn ??= ep.bEndpointAddress;
            } else {
              bOut ??= ep.bEndpointAddress;
            }
          }
          final matches = interfaceId == null ? (bIn != null && bOut != null) : alt.bInterfaceNumber == interfaceId;
          if (matches && bIn != null && bOut != null) {
            pick = {'id': alt.bInterfaceNumber, 'in': bIn, 'out': bOut};
            if (alt.bInterfaceClass == 6 || interfaceId != null) break; // prefer PTP class
          }
        }
        usb.freeConfig(cfgOut.value);
        calloc.free(cfgOut);
        if (pick == null) {
          usb.close(handle);
          handle = nullptr;
          return {'error': 'no bulk interface'};
        }
        final rcClaim = usb.claimInterface(handle, pick['id']!);
        if (rcClaim != 0) {
          usb.close(handle);
          handle = nullptr;
          return {'error': rcClaim == -6 ? 'busy' : 'claim failed ($rcClaim)'};
        }
        claimed = pick['id']!;
        epIn = pick['in']!;
        epOut = pick['out']!;
        return {'interfaceId': claimed, 'bulkIn': epIn, 'bulkOut': epOut};
      }
      return {'error': 'device gone'};
    } finally {
      if (n >= 0) usb.freeDeviceList(devs, 1);
      calloc.free(listOut);
    }
  }

  void closeDevice() {
    if (handle != nullptr) {
      if (claimed >= 0) usb.releaseInterface(handle, claimed);
      usb.close(handle);
    }
    handle = nullptr;
    claimed = -1;
  }

  final port = ReceivePort();
  ready.send(port.sendPort);
  port.listen((msg) {
    final cmd = msg as _Cmd;
    try {
      switch (cmd.op) {
        case 'list':
          cmd.reply.send(list(vidFilter: cmd.args['vid'] as int?));
        case 'open':
          cmd.reply.send(openDevice(cmd.args['name'] as String, cmd.args['interfaceId'] as int?));
        case 'close':
          closeDevice();
          cmd.reply.send(null);
        case 'bulkOut':
          final data = cmd.args['data'] as Uint8List;
          final buf = calloc<Uint8>(data.length);
          buf.asTypedList(data.length).setAll(0, data);
          final sent = calloc<Int32>();
          final rc = usb.bulkTransfer(handle, epOut, buf, data.length, sent, cmd.args['timeoutMs'] as int);
          final n = sent.value;
          calloc.free(sent);
          calloc.free(buf);
          cmd.reply.send(rc == 0 ? n : {'error': 'bulkOut $rc'});
        case 'bulkIn':
          final max = cmd.args['maxLen'] as int;
          final buf = calloc<Uint8>(max);
          final got = calloc<Int32>();
          final rc = usb.bulkTransfer(handle, epIn, buf, max, got, cmd.args['timeoutMs'] as int);
          final out = rc == 0 ? Uint8List.fromList(buf.asTypedList(got.value)) : null;
          calloc.free(got);
          calloc.free(buf);
          cmd.reply.send(out ?? {'error': 'bulkIn $rc'});
        case 'quit':
          closeDevice();
          usb.exit_(ctx);
          cmd.reply.send(null);
          port.close();
      }
    } catch (e) {
      cmd.reply.send({'error': e.toString()});
    }
  });
}

// ---------------------------------------------------------------- public host

/// libusb-backed [UsbHost] for Linux / macOS / Windows. `vidFilter` defaults to Fujifilm.
class LibusbHost implements UsbHost, UsbLink {
  LibusbHost({this.vidFilter = 0x04cb, Duration pollEvery = const Duration(seconds: 2)}) : _pollEvery = pollEvery;

  final int? vidFilter;
  final Duration _pollEvery;
  SendPort? _worker_;
  final _events = StreamController<UsbEvent>.broadcast();
  Timer? _poll;
  Set<String> _lastSeen = {};

  Future<SendPort> _ensure() async {
    if (_worker_ != null) return _worker_!;
    final ready = ReceivePort();
    await Isolate.spawn(_worker, ready.sendPort, debugName: 'libusb');
    _worker_ = await ready.first as SendPort;
    _poll ??= Timer.periodic(_pollEvery, (_) => _pollDevices());
    return _worker_!;
  }

  Future<Object?> _call(String op, [Map<String, Object?> args = const {}]) async {
    final w = await _ensure();
    final reply = ReceivePort();
    w.send(_Cmd(op, reply.sendPort, args));
    final r = await reply.first;
    reply.close();
    if (r is Map && r['error'] != null) throw StateError('libusb: ${r['error']}');
    return r;
  }

  Future<void> _pollDevices() async {
    try {
      final devs = await listDevices();
      final now = devs.map((d) => '${d.name}/${d.idString}').toSet();
      for (final d in devs) {
        if (!_lastSeen.contains('${d.name}/${d.idString}')) {
          _events.add(UsbEvent(attached: true, deviceName: d.name, vid: d.vid));
        }
      }
      for (final gone in _lastSeen.difference(now)) {
        _events.add(UsbEvent(attached: false, deviceName: gone.split('/').first, vid: vidFilter));
      }
      _lastSeen = now;
    } catch (_) {}
  }

  @override
  UsbLink get link => this;

  @override
  Stream<UsbEvent> get events => _events.stream;

  @override
  Future<List<UsbDeviceInfo>> listDevices() async {
    final r = await _call('list', {'vid': vidFilter}) as List;
    return r.map((e) => UsbDeviceInfo.fromMap((e as Map).cast<String, Object?>())).toList();
  }

  /// On desktop there is no permission dialog — openability *is* permission (udev/WinUSB decide).
  @override
  Future<bool> requestPermission(String name) async {
    final devs = await listDevices();
    return devs.where((d) => d.name == name).firstOrNull?.hasPermission ?? false;
  }

  @override
  Future<Map> open(String name, {int? interfaceId}) async {
    // Linux: GNOME's gvfsd-gphoto2 auto-claims PTP cameras and respawns quickly. Evict and
    // race it a few times — the udev ENV{ID_GPHOTO2}="" rule (docs/ops/kata-desktop.md)
    // prevents this permanently.
    for (var attempt = 0; ; attempt++) {
      try {
        return (await _call('open', {'name': name, 'interfaceId': interfaceId})) as Map;
      } on StateError catch (e) {
        if (!e.message.contains('busy') || !Platform.isLinux || attempt >= 5) rethrow;
        try {
          await Process.run('pkill', ['-f', 'gvfsd-gphoto2']);
        } catch (_) {}
        await Future<void>.delayed(Duration(milliseconds: 150 + attempt * 150));
      }
    }
  }

  @override
  Future<void> close() async => _call('close');

  @override
  Future<int> bulkOut(Uint8List data, {int timeoutMs = 5000}) async => (await _call('bulkOut', {'data': data, 'timeoutMs': timeoutMs})) as int;

  @override
  Future<Uint8List> bulkIn(int maxLen, {int timeoutMs = 5000}) async => (await _call('bulkIn', {'maxLen': maxLen, 'timeoutMs': timeoutMs})) as Uint8List;

  Future<void> dispose() async {
    _poll?.cancel();
    if (_worker_ != null) {
      try {
        await _call('quit');
      } catch (_) {}
    }
    await _events.close();
  }
}
