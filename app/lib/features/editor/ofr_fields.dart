import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

/// Mutates the recipe under edit.
typedef OfrSet = void Function(OfrRecipe Function(OfrRecipe));

/// The OFR field controls, shared by the phone editor and the desktop two-pane editor so the
/// two can't drift. Layout stays with the caller; only the fields and their rules live here.
class OfrFields {
  static Widget _gap() => const SizedBox(height: 10);
  static Widget _two(Widget a, Widget b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  /// Film simulation, DR, grain and colour-chrome.
  static List<Widget> look(OfrRecipe r, OfrSet set) => [
        KataPickerRow(
          label: 'Film simulation',
          value: r.filmSimulation,
          options: OfrEnums.filmSims,
          // switching colour↔mono drops the fields the other family forbids, so validation never traps you
          onChanged: (v) => set((x) => OfrEnums.isMonoName(v)
              ? x.copyWith(filmSimulation: v, clearColor: true, clearColorChrome: true)
              : x.copyWith(filmSimulation: v, clearMonochromatic: true, color: x.color ?? 0)),
        ),
        KataPickerRow(label: 'Dynamic range', value: r.dynamicRange, hint: 'Camera default', options: OfrEnums.dynamicRanges, onChanged: (v) => set((x) => x.copyWith(dynamicRange: v))),
        KataPickerRow(label: 'D range priority', value: r.dRangePriority, options: OfrEnums.dRangePriorities, onChanged: (v) => set((x) => x.copyWith(dRangePriority: v))),
        KataPickerRow(label: 'Grain', value: r.grainRoughness, options: OfrEnums.grainRoughness, onChanged: (v) => set((x) => x.copyWith(grainRoughness: v, clearGrainSize: v == 'Off'))),
        KataPickerRow(label: 'Grain size', value: r.grainSize, hint: '—', enabled: r.grainRoughness != 'Off', options: OfrEnums.grainSizes, onChanged: (v) => set((x) => x.copyWith(grainSize: v))),
        KataPickerRow(label: 'Color chrome effect', value: r.colorChromeEffect, hint: 'Off', options: OfrEnums.effects, onChanged: (v) => set((x) => x.copyWith(colorChromeEffect: v))),
        KataPickerRow(label: 'Color chrome FX blue', value: r.colorChromeFxBlue, hint: 'Off', options: OfrEnums.effects, onChanged: (v) => set((x) => x.copyWith(colorChromeFxBlue: v))),
      ];

  static List<Widget> whiteBalance(OfrRecipe r, OfrSet set) => [
        KataPickerRow(
          label: 'Mode',
          value: r.whiteBalance,
          options: OfrEnums.wbModes,
          onChanged: (v) => set((x) => x.copyWith(whiteBalance: v, wbKelvin: v == 'Kelvin' ? (x.wbKelvin ?? 5500) : null, clearKelvin: v != 'Kelvin')),
        ),
        if (r.whiteBalance == 'Kelvin') ...[
          _gap(),
          KataStepper(label: 'Kelvin', value: r.wbKelvin ?? 5500, min: 2500, max: 10000, step: 100, format: (v) => '${v.toInt()}K', onChanged: (v) => set((x) => x.copyWith(wbKelvin: v.toInt()))),
        ],
        _gap(),
        _two(
          KataStepper(label: 'WB shift R', value: r.whiteBalanceRed, min: -9, max: 9, onChanged: (v) => set((x) => x.copyWith(whiteBalanceRed: v.toInt()))),
          KataStepper(label: 'WB shift B', value: r.whiteBalanceBlue, min: -9, max: 9, onChanged: (v) => set((x) => x.copyWith(whiteBalanceBlue: v.toInt()))),
        ),
      ];

  /// Tone curve, colour, NR, and the mono-only shifts.
  static List<Widget> tone(OfrRecipe r, OfrSet set) {
    final mono = OfrEnums.isMonoName(r.filmSimulation);
    return [
      _two(
        KataStepper(label: 'Highlight', value: r.highlight ?? 0, min: -2, max: 4, step: 0.5, onChanged: (v) => set((x) => x.copyWith(highlight: v))),
        KataStepper(label: 'Shadow', value: r.shadow ?? 0, min: -2, max: 4, step: 0.5, onChanged: (v) => set((x) => x.copyWith(shadow: v))),
      ),
      _gap(),
      _two(
        KataStepper(label: 'Color', value: r.color ?? 0, min: -4, max: 4, enabled: !mono, onChanged: (v) => set((x) => x.copyWith(color: v.toInt()))),
        KataStepper(label: 'Sharpness', value: r.sharpness, min: -4, max: 4, onChanged: (v) => set((x) => x.copyWith(sharpness: v.toInt()))),
      ),
      _gap(),
      _two(
        KataStepper(label: 'High ISO NR', value: r.highIsoNr, min: -4, max: 4, onChanged: (v) => set((x) => x.copyWith(highIsoNr: v.toInt()))),
        KataStepper(label: 'Clarity', value: r.clarity, min: -5, max: 5, onChanged: (v) => set((x) => x.copyWith(clarity: v.toInt()))),
      ),
      if (mono) ...[
        _gap(),
        _two(
          KataStepper(label: 'Warm / cool', value: r.monochromaticColorWarmCool ?? 0, min: -9, max: 9, onChanged: (v) => set((x) => x.copyWith(monochromaticColorWarmCool: v.toInt()))),
          KataStepper(label: 'Magenta / green', value: r.monochromaticColorMagentaGreen ?? 0, min: -9, max: 9, onChanged: (v) => set((x) => x.copyWith(monochromaticColorMagentaGreen: v.toInt()))),
        ),
      ],
    ];
  }

  /// Sensor generations this recipe declares.
  static Widget sensorChips(OfrRecipe r, OfrSet set) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final s in OfrEnums.sensors.take(7))
            KataChip(
              label: s,
              selected: r.sensors.contains(s),
              onTap: () => set((x) => x.copyWith(sensors: x.sensors.contains(s) ? x.sensors.where((e) => e != s).toList() : [...x.sensors, s])),
            ),
        ],
      );
}
