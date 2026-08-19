/// Fujifilm bodies Kata knows about, with what we believe each can do over USB.
///
/// `usbWrite`: full = X-Processor 5 bodies that expose the preset properties (D18C…) — tested on the
/// X-S20, expected on the rest; probe = older RAW-conversion-capable bodies that may or may not
/// advertise the properties (the app checks GetDeviceInfo at connect); none = read-only / unsupported.
enum UsbWrite { full, probe, none }

class KnownBody {
  const KnownBody(this.model, {required this.slug, required this.generation, required this.slots, required this.usbWrite, this.pid, this.tested = false, this.note});
  final String model;
  /// Asset slug for line art: `assets/cameras/<slug>.svg`.
  final String slug;
  final String generation;
  final int slots;
  final UsbWrite usbWrite;
  final int? pid;
  final bool tested;
  final String? note;

  static const all = <KnownBody>[
    // ---- X-Trans V / X-Processor 5 — preset protocol present
    KnownBody('X-S20', slug: 'x-s20', generation: 'X-Trans V', slots: 4, usbWrite: UsbWrite.full, pid: 0x02f7, tested: true, note: 'Verified end-to-end (fw 3.30)'),
    KnownBody('X-T5', slug: 'x-t5', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x02fc),
    KnownBody('X-H2', slug: 'x-h2', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x02f2),
    KnownBody('X-H2S', slug: 'x-h2s', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x02f0),
    KnownBody('X-T50', slug: 'x-t50', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full),
    KnownBody('X-M5', slug: 'x-m5', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x030c, note: 'Slot count unverified'),
    KnownBody('X-E5', slug: 'x-e5', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x0313),
    KnownBody('X-T30 III', slug: 'x-t30-iii', generation: 'X-Trans V', slots: 4, usbWrite: UsbWrite.full, note: 'Slot count unverified'),
    KnownBody('X100VI', slug: 'x100vi', generation: 'X-Trans V', slots: 7, usbWrite: UsbWrite.full, pid: 0x0305, note: 'Preset read/write reported by FilmKit'),
    KnownBody('GFX100 II', slug: 'gfx100-ii', generation: 'GFX', slots: 7, usbWrite: UsbWrite.full, pid: 0x02fe),
    KnownBody('GFX100S II', slug: 'gfx100s-ii', generation: 'GFX', slots: 7, usbWrite: UsbWrite.full),
    KnownBody('GFX100RF', slug: 'gfx100rf', generation: 'GFX', slots: 7, usbWrite: UsbWrite.full),
    // ---- X-Trans IV / X-Processor 4 — RAW conversion protocol, preset props unconfirmed
    KnownBody('X-T4', slug: 'x-t4', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe),
    KnownBody('X-S10', slug: 'x-s10', generation: 'X-Trans IV', slots: 4, usbWrite: UsbWrite.probe, pid: 0x02ea),
    KnownBody('X-Pro3', slug: 'x-pro3', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe),
    KnownBody('X100V', slug: 'x100v', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe),
    KnownBody('X-T3', slug: 'x-t3', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe, pid: 0x02dd),
    KnownBody('X-T30', slug: 'x-t30', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe, pid: 0x02e3),
    KnownBody('X-T30 II', slug: 'x-t30-ii', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe),
    KnownBody('X-E4', slug: 'x-e4', generation: 'X-Trans IV', slots: 7, usbWrite: UsbWrite.probe),
    KnownBody('GFX100S', slug: 'gfx100s', generation: 'GFX', slots: 7, usbWrite: UsbWrite.probe, pid: 0x02ea),
    KnownBody('GFX100', slug: 'gfx100', generation: 'GFX', slots: 7, usbWrite: UsbWrite.probe, pid: 0x02de),
    KnownBody('GFX50S II', slug: 'gfx50s-ii', generation: 'GFX', slots: 7, usbWrite: UsbWrite.probe),
    // ---- X-Trans III and earlier — connect / read only
    KnownBody('X-T2', slug: 'x-t2', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02cd),
    KnownBody('X-Pro2', slug: 'x-pro2', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02cb),
    KnownBody('X-H1', slug: 'x-h1', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02d7),
    KnownBody('X-T20', slug: 'x-t20', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02d4),
    KnownBody('X100F', slug: 'x100f', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02d1),
    KnownBody('X-E3', slug: 'x-e3', generation: 'X-Trans III', slots: 7, usbWrite: UsbWrite.none, pid: 0x02d6),
    KnownBody('GFX 50S', slug: 'gfx50s', generation: 'GFX', slots: 7, usbWrite: UsbWrite.none, pid: 0x02d3),
    KnownBody('GFX 50R', slug: 'gfx50r', generation: 'GFX', slots: 7, usbWrite: UsbWrite.none, pid: 0x02dc),
    KnownBody('X-T1', slug: 'x-t1', generation: 'X-Trans II', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-T10', slug: 'x-t10', generation: 'X-Trans II', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X100T', slug: 'x100t', generation: 'X-Trans II', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-E2', slug: 'x-e2', generation: 'X-Trans II', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-Pro1', slug: 'x-pro1', generation: 'X-Trans I', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-E1', slug: 'x-e1', generation: 'X-Trans I', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-T200', slug: 'x-t200', generation: 'Bayer', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('X-A7', slug: 'x-a7', generation: 'Bayer', slots: 7, usbWrite: UsbWrite.none),
    KnownBody('XF10', slug: 'xf10', generation: 'Bayer', slots: 7, usbWrite: UsbWrite.none),
  ];

  /// Match a `GetDeviceInfo.Model` string (e.g. "X-S20", "FUJIFILM X-T5") to a known body.
  static KnownBody? forModel(String model) {
    final m = _norm(model);
    for (final b in all) {
      if (_norm(b.model) == m) return b;
    }
    // longest model name contained in the string wins (handles "FUJIFILM X-T30 II" vs "X-T30")
    KnownBody? best;
    for (final b in all) {
      if (m.contains(_norm(b.model)) && (best == null || b.model.length > best.model.length)) best = b;
    }
    return best;
  }

  static String _norm(String s) => s.toUpperCase().replaceAll('FUJIFILM', '').replaceAll(RegExp(r'[\s_]+'), '').trim();
}
