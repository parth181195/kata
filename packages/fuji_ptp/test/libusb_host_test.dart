@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';

/// Runs against the real host libusb (flutter test executes on the host VM).
/// Asserts enumeration works — no camera required.
void main() {
  test('LibusbHost enumerates host USB devices without crashing', () async {
    final host = LibusbHost(vidFilter: null, pollEvery: const Duration(hours: 1));
    final devs = await host.listDevices();
    stdout.writeln('libusb sees ${devs.length} devices');
    for (final d in devs.take(6)) {
      stdout.writeln('  ${d.idString} ${d.product ?? ''} perm=${d.hasPermission} ifs=${d.interfaces.length}');
    }
    expect(devs, isNotEmpty); // a real machine always has hubs/root devices
    // fuji filter shape works too (may be empty without a camera)
    final fuji = LibusbHost(pollEvery: const Duration(hours: 1));
    final f = await fuji.listDevices();
    stdout.writeln('fuji devices: ${f.map((d) => d.idString).toList()}');
    expect(f.every((d) => d.vid == 0x04cb), isTrue);
    await fuji.dispose();
    await host.dispose();
  });
}
