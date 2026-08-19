import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fuji/preset.dart';
import 'probe.dart';

void main() => runApp(const ProbeApp());

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuji Probe',
      theme: ThemeData(colorSchemeSeed: Colors.green, brightness: Brightness.dark, useMaterial3: true),
      home: const ProbePage(),
    );
  }
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  final ProbeSession s = ProbeSession();
  final ScrollController _scroll = ScrollController();
  int slot = 1;
  int filmSim = 12; // Acros

  @override
  void initState() {
    super.initState();
    s.addListener(_onChange);
  }

  void _onChange() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    s.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // already logged by session
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = s.connected && s.sessionOpen;
    final status = !s.connected
        ? 'Not connected'
        : !s.sessionOpen
            ? 'USB open, PTP session failed'
            : '${s.info?.manufacturer ?? ''} ${s.info?.model ?? device()}  fw ${s.info?.deviceVersion ?? '?'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuji Probe'),
        actions: [
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: s.logText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log copied')));
              }
            },
          ),
          IconButton(tooltip: 'Clear log', icon: const Icon(Icons.delete_outline), onPressed: s.clearLog),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(conn ? Icons.usb : Icons.usb_off, color: conn ? Colors.greenAccent : Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(status, style: Theme.of(context).textTheme.bodyMedium)),
                if (s.busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: s.busy ? null : () => _guard(conn ? s.disconnect : s.connect),
                  icon: Icon(conn ? Icons.link_off : Icons.link),
                  label: Text(conn ? 'Disconnect' : 'Connect'),
                ),
                OutlinedButton(
                  onPressed: !conn || s.busy ? null : () => _guard(s.readSlots),
                  child: const Text('Read slots C1–C7'),
                ),
                OutlinedButton(
                  onPressed: !conn || s.busy ? null : () => _guard(s.dumpAllProps),
                  child: const Text('Dump all props'),
                ),
                OutlinedButton(
                  onPressed: !conn || s.busy ? null : () => _guard(s.readCurrentState),
                  child: const Text('D212'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('Slot '),
                DropdownButton<int>(
                  value: slot,
                  items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text('C$i'))],
                  onChanged: (v) => setState(() => slot = v ?? 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    value: filmSim,
                    isExpanded: true,
                    items: [
                      for (final e in filmSimLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => filmSim = v ?? 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: !conn || s.busy ? null : () => _guard(() => s.testWriteFilmSim(slot, filmSim)),
                  child: const Text('Test write film sim'),
                ),
                FilledButton.tonal(
                  onPressed: !conn || s.busy ? null : () => _guard(() => s.testWriteName(slot, 'PROBE C$slot')),
                  child: const Text('Test write name'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  s.lines.isEmpty
                      ? 'Camera: CONNECTION MODE = USB RAW CONV./BACKUP RESTORE, '
                          'USB POWER SUPPLY/COMM = POWER SUPPLY OFF/COMM ON. '
                          'Plug in, power camera on, then Connect.'
                      : s.logText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String device() => s.device == null ? '' : '${s.device!.product ?? ''} (${s.device!.idString})';
}
