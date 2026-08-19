import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:ofr/ofr.dart';

import '../../core/fuji/camera_service.dart';

/// Kodachrome 64 (OFR README example) used as the built-in write test.
const kSampleOfr = '''
{"v":1,"name":"Kodachrome 64","sensors":["X-Trans IV"],"source_attribution":"Fuji X Weekly",
"film_simulation":"Classic Chrome","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Weak","grain_size":"Small",
"color_chrome_effect":"Weak","color_chrome_fx_blue":"Off","white_balance":"Daylight","white_balance_red":2,"white_balance_blue":-5,
"highlight":-1,"shadow":0.5,"color":2,"sharpness":-2,"high_iso_nr":-4,"clarity":0}''';

class ProbeScreen extends ConsumerStatefulWidget {
  const ProbeScreen({super.key});
  @override
  ConsumerState<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends ConsumerState<ProbeScreen> {
  final _log = <String>[];
  final _ofrCtrl = TextEditingController(text: kSampleOfr);
  int _slot = 2;

  void _l(String s) => setState(() => _log.add(s));

  Future<void> _writeOfr() async {
    final OfrRecipe r;
    try {
      r = OfrRecipe.fromJson(jsonDecode(_ofrCtrl.text) as Map<String, dynamic>);
    } catch (e) {
      _l('JSON error: $e');
      return;
    }
    final issues = OfrValidator.validate(r);
    for (final i in issues) {
      _l('${i.severity.name}: $i');
    }
    if (OfrValidator.hasErrors(issues)) return;
    _l('hash=${OfrHasher.compute(r)}');
    final m = OfrMapper.toPreset(r);
    for (final n in m.notes) {
      _l('note: $n');
    }
    try {
      final res = await ref.read(cameraServiceProvider.notifier).writeRecipe(_slot, m.value);
      _l('write C$_slot ok=${res.ok} written=${res.written.length} skipped=${res.skipped.length}');
      for (final w in res.warnings) {
        _l('  warn: $w');
      }
      _l('>>> Turn the mode dial off C$_slot and back; it should show ${FilmSim.labels[m.value.filmSim]}.');
    } catch (e) {
      _l('write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(cameraServiceProvider);
    final svc = ref.read(cameraServiceProvider.notifier);
    final status = switch (st) {
      CameraDisconnected(:final reason) => 'Disconnected${reason == null ? '' : ' (${reason.name})'}',
      CameraConnecting(:final step) => 'Connecting: $step',
      CameraReady(:final caps, :final busyWith) =>
        '${caps.model} fw ${caps.firmware} · ${caps.slotCount} slots${busyWith == null ? '' : ' · $busyWith'}',
      CameraFailed(:final reason, :final detail) => 'Failed: ${reason.name} ${detail ?? ''}',
    };
    final ready = st is CameraReady && !st.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Kata · probe'), actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: _log.join('\n')))),
      ]),
      body: Column(children: [
        ListTile(title: Text(status)),
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: st is CameraReady ? svc.disconnect : svc.connect,
              child: Text(st is CameraReady ? 'Disconnect' : 'Connect')),
          OutlinedButton(onPressed: ready ? svc.refreshSlots : null, child: const Text('Read slots')),
          DropdownButton<int>(
              value: _slot,
              items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text('C$i'))],
              onChanged: (v) => setState(() => _slot = v ?? 2)),
          FilledButton.tonal(onPressed: ready ? _writeOfr : null, child: const Text('Write OFR → slot')),
        ]),
        if (st is CameraReady)
          SizedBox(
            height: 120,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < st.slots.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 150,
                      child: Text(
                          'C${i + 1} ${st.slots[i].name}\n${FilmSim.labels[st.slots[i].filmSim]}\nDR ${st.slots[i].dynamicRange == kDrAuto ? 'Auto' : st.slots[i].dynamicRange}\n'
                          '${jsonEncode(OfrMapper.fromPreset(st.slots[i], sensors: OfrMapper.sensorsForModel(st.caps.model)).toJson()).length} B OFR'),
                    ),
                  ),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
              controller: _ofrCtrl,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(labelText: 'OFR JSON')),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(_log.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
          ),
        ),
      ]),
    );
  }
}
