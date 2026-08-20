import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

/// Everything that goes wrong between a camera and a USB port, in one place. The steps live
/// on the connect screen; this is the long form for when the short form didn't work.
Future<void> showConnectionGuide(BuildContext context) =>
    showKataSheet<void>(context, maxWidth: 620, builder: (c) => const _Guide());

class _Line {
  const _Line(this.text, {this.sub}) : mark = '✓';
  const _Line.no(this.text, {this.sub}) : mark = '✗';
  const _Line.step(this.text, {required this.sub}) : mark = '';
  final String text;
  final String? sub;
  final String mark;
}

class _Section {
  const _Section(this.title, this.lines);
  final String title;
  final List<_Line> lines;
}

bool get _onPhone => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

List<_Section> _sections() => [
      _Section('Connecting', [
        const _Line.step('Set the camera menu, once per body',
            sub: 'MENU → CONNECTION SETTING → USB MODE → USB RAW CONV./BACKUP RESTORE, and USB POWER SUPPLY → OFF (COMM ON).'),
        _Line.step('Camera off, then plug in',
            sub: 'A USB-C data cable, straight from the camera to ${_onPhone ? 'the phone' : 'the computer'}.'),
        if (_onPhone) const _Line.step('Accept the USB dialog', sub: 'Tick "Always allow" and Android stops asking for this camera.'),
        const _Line.step('Power the camera on, then Connect',
            sub: 'Kata reads your C-slots first. Nothing is written until you review the diff.'),
      ]),
      const _Section('The cable decides', [
        _Line('A data cable — the one in the camera box is the safe bet'),
        _Line('Most phone charging cables carry data and work fine'),
        _Line.no('Charge-only cables have no data lines: the camera charges, nothing appears'),
        _Line.no('Hubs, dongles and monitor ports drop the camera — plug straight in'),
      ]),
      if (_onPhone)
        const _Section('On Android', [
          _Line('USB OTG has to be on. Most phones do it by themselves'),
          _Line('If not: Settings → search "OTG" → enable OTG / USB OTG', sub: 'Some phones only show the toggle while something is plugged in.'),
          _Line('Developing over wireless debugging keeps the USB port free for the camera'),
          _Line('Screen off is fine — Android keeps the connection while Kata writes'),
        ])
      else
        const _Section('On Linux', [
          _Line('The .deb installs a udev rule so Kata can open the camera without sudo', sub: 'Replug the camera once after installing.'),
          _Line('Running the AppImage or a tarball? Install the rule by hand', sub: 'docs/ops/kata-desktop.md has the one-liner.'),
          _Line('If your file manager opens a camera window, Kata takes the camera back on Connect', sub: 'GNOME mounts it through gvfs; Kata evicts it.'),
          _Line.no('Front-panel hubs and monitor USB ports are the usual reason a camera never shows up',
              sub: 'Use a port on the machine itself.'),
        ]),
      const _Section('When it goes wrong', [
        _Line('No camera found',
            sub: 'Camera on, USB MODE on USB RAW CONV./BACKUP RESTORE. Then unplug, replug, and try a different cable — this is a charge-only cable most of the time.'),
        _Line('Permission denied',
            sub: 'Unplug and replug, and accept the dialog. If it never appears: Settings → Apps → Kata → Permissions. On Linux the udev rule hasn\'t taken effect yet — replug, or log out and back in.'),
        _Line("Couldn't claim the camera",
            sub: 'Something else has it open — a gallery importer, a file manager, darktable, another Kata window. Close it and press Connect again.'),
        _Line('Camera says Busy, or drops out mid-write',
            sub: 'Give it ten seconds, unplug, replug. If it keeps happening, power-cycle the camera: a wedged USB endpoint clears on a fresh boot.'),
        _Line("Won't reconnect after a disconnect",
            sub: 'The camera holds the old session for a moment. Wait about half a minute and replug.'),
        _Line('The camera stopped charging',
            sub: 'Kata closes the USB session on Eject and on quit, which hands the port back. If the lamp stays dark, unplug and replug.'),
        _Line('Wrote a kata, but the photos look the same',
            sub: 'Turn the mode dial off that slot and back — the camera only loads a slot when you select it. Shoot in P/A/S/M; AUTO and the SP scene modes ignore custom settings.'),
      ]),
      const _Section('Before you write', [
        _Line('Keep some battery in the camera — a slot takes a few seconds'),
        _Line('A write replaces the whole slot. Kata backs it up first and can put it back'),
        _Line('Settings the camera refuses are listed after the write, with the reason'),
      ]),
    ];

class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return KataSheet(
      eyebrow: 'Camera',
      title: 'Connection guide',
      children: [
        for (final s in _sections()) ...[
          KataSectionHeader(s.title),
          const SizedBox(height: 10),
          for (var i = 0; i < s.lines.length; i++) ...[
            if (i > 0) ...[const SizedBox(height: 11), const DottedDivider(), const SizedBox(height: 11)],
            _LineRow(line: s.lines[i], n: s.lines[i].mark.isEmpty ? i + 1 : null),
          ],
          const SizedBox(height: 22),
        ],
        Text('Something else? The camera work is open source — open an issue with your body and firmware.',
            style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5)),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.n});
  final _Line line;
  final int? n;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final bad = line.mark == '✗';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 22,
        child: n != null
            ? Text('$n', style: KataType.monoStyle(size: 10, weight: FontWeight.w500, color: p.muted, height: 1.5))
            : Text(line.mark, style: KataType.monoStyle(size: 11, weight: FontWeight.w500, color: bad ? p.red : p.dim, height: 1.35)),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.text, style: KataType.bodyStyle(size: 12.5, weight: FontWeight.w600, color: bad ? p.muted : p.fg, height: 1.35)),
          if (line.sub != null) ...[
            const SizedBox(height: 4),
            Text(line.sub!, style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.55)),
          ],
        ]),
      ),
    ]);
  }
}
