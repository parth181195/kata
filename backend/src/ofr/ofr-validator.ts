import { OfrEnums, isMonoFilmSim } from './ofr-enums';
import { num, OfrDoc, str, strList } from './ofr-recipe';

export interface OfrIssue {
  field: string;
  message: string;
  severity: 'error' | 'warning';
}

export const hasErrors = (issues: OfrIssue[]): boolean =>
  issues.some((i) => i.severity === 'error');

/** OFR v1 structural validation — mirrors packages/ofr (Dart) rule for rule. */
export function validateOfr(doc: OfrDoc): OfrIssue[] {
  const out: OfrIssue[] = [];
  const err = (field: string, message: string) =>
    out.push({ field, message, severity: 'error' });
  const warn = (field: string, message: string) =>
    out.push({ field, message, severity: 'warning' });
  const range = (
    f: string,
    v: number | undefined,
    min: number,
    max: number,
  ) => {
    if (v !== undefined && (v < min || v > max)) err(f, `range ${min}…${max}`);
  };
  const oneOf = (
    f: string,
    v: unknown,
    allowed: string[],
    required = false,
  ) => {
    if (v === undefined || v === null) {
      if (required) err(f, 'required');
      return;
    }
    if (typeof v !== 'string' || !allowed.includes(v)) {
      err(
        f,
        `unknown value "${typeof v === 'string' ? v : JSON.stringify(v)}"`,
      );
    }
  };
  const halfStep = (f: string, v: number | undefined) => {
    if (v !== undefined && (v * 2) % 1 !== 0)
      err(f, 'whole or half steps only');
  };

  const v = num(doc.v) ?? 1;
  if (v !== 1) err('v', `unsupported version ${v}`);
  if ((str(doc.name) ?? '').length > 25)
    warn('name', 'longer than 25 chars; will be truncated on camera');
  for (const s of strList(doc.sensors)) {
    if (!OfrEnums.sensors.includes(s)) warn('sensors', `unknown sensor "${s}"`);
  }

  oneOf('film_simulation', doc.film_simulation, OfrEnums.filmSims, true);
  oneOf('dynamic_range', doc.dynamic_range, OfrEnums.dynamicRanges);
  oneOf(
    'd_range_priority',
    doc.d_range_priority,
    OfrEnums.dRangePriorities,
    true,
  );
  oneOf('grain_roughness', doc.grain_roughness, OfrEnums.grainRoughness, true);
  oneOf('grain_size', doc.grain_size, OfrEnums.grainSizes);
  oneOf('color_chrome_effect', doc.color_chrome_effect, OfrEnums.effects);
  oneOf('color_chrome_fx_blue', doc.color_chrome_fx_blue, OfrEnums.effects);
  oneOf('white_balance', doc.white_balance, OfrEnums.wbModes, true);

  range('wb_kelvin', num(doc.wb_kelvin), 2500, 10000);
  range('white_balance_red', num(doc.white_balance_red), -9, 9);
  range('white_balance_blue', num(doc.white_balance_blue), -9, 9);
  range('highlight', num(doc.highlight), -2, 4);
  range('shadow', num(doc.shadow), -2, 4);
  halfStep('highlight', num(doc.highlight));
  halfStep('shadow', num(doc.shadow));
  range('color', num(doc.color), -4, 4);
  range('sharpness', num(doc.sharpness), -4, 4);
  range('high_iso_nr', num(doc.high_iso_nr), -4, 4);
  range('clarity', num(doc.clarity), -5, 5);
  range(
    'monochromatic_color_warm_cool',
    num(doc.monochromatic_color_warm_cool),
    -9,
    9,
  );
  range(
    'monochromatic_color_magenta_green',
    num(doc.monochromatic_color_magenta_green),
    -9,
    9,
  );

  const drp = str(doc.d_range_priority) ?? 'Off';
  if (drp !== 'Off') {
    if (doc.dynamic_range !== undefined)
      err('dynamic_range', 'omit when d_range_priority is not Off');
    if (doc.highlight !== undefined)
      err('highlight', 'omit when d_range_priority is not Off');
    if (doc.shadow !== undefined)
      err('shadow', 'omit when d_range_priority is not Off');
  }
  const grain = str(doc.grain_roughness) ?? 'Off';
  if (grain === 'Off' && doc.grain_size !== undefined)
    err('grain_size', 'omit when grain_roughness is Off');
  if (
    grain !== 'Off' &&
    doc.grain_size === undefined &&
    OfrEnums.grainRoughness.includes(grain)
  )
    warn('grain_size', 'missing; will use Small');

  const mono = isMonoFilmSim(str(doc.film_simulation) ?? '');
  if (mono) {
    if (doc.color !== undefined)
      err('color', 'omit for monochrome film simulations');
    if (doc.color_chrome_effect !== undefined)
      err('color_chrome_effect', 'omit for monochrome film simulations');
    if (doc.color_chrome_fx_blue !== undefined)
      err('color_chrome_fx_blue', 'omit for monochrome film simulations');
  } else {
    if (doc.monochromatic_color_warm_cool !== undefined)
      err(
        'monochromatic_color_warm_cool',
        'only for monochrome film simulations',
      );
    if (doc.monochromatic_color_magenta_green !== undefined)
      err(
        'monochromatic_color_magenta_green',
        'only for monochrome film simulations',
      );
  }
  if (str(doc.white_balance) === 'Kelvin') {
    if (doc.wb_kelvin === undefined)
      err('wb_kelvin', 'required when white_balance is Kelvin');
  } else if (doc.wb_kelvin !== undefined) {
    err('wb_kelvin', 'omit unless white_balance is Kelvin');
  }
  return out;
}
