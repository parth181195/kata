import { canonicalJson, hasErrors, ofrHash, validateOfr } from './index';

const kodachrome = {
  v: 1,
  name: 'Kodachrome 64',
  sensors: ['X-Trans IV'],
  source_url: 'https://fujixweekly.com/2020/05/27/...',
  source_attribution: 'Fuji X Weekly',
  film_simulation: 'Classic Chrome',
  dynamic_range: 'DR400',
  d_range_priority: 'Off',
  grain_roughness: 'Weak',
  grain_size: 'Small',
  color_chrome_effect: 'Weak',
  color_chrome_fx_blue: 'Off',
  white_balance: 'Daylight',
  white_balance_red: 2,
  white_balance_blue: -5,
  highlight: -1,
  shadow: 0.5,
  color: 2,
  sharpness: -2,
  high_iso_nr: -4,
  clarity: 0,
};

const fields = (doc: Record<string, unknown>) =>
  validateOfr(doc).map((i) => i.field);

describe('ofr hasher', () => {
  it('canonical json', () => {
    expect(canonicalJson({ b: 2.0, a: 0.5, c: ['x'] })).toBe(
      '{"a":0.5,"b":2,"c":["x"]}',
    );
  });
  it('README vectors', () => {
    expect(ofrHash(kodachrome)).toBe(
      'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176',
    );
    expect(ofrHash(kodachrome, 'v1SettingsOnly')).toBe(
      'b8a167b1a95c0d4aaede28283895407bd11a8b84f96c74521433829c5dcfd565',
    );
  });
  it('name/source do not affect hash; sensors do', () => {
    expect(ofrHash({ ...kodachrome, name: 'x', source_url: 'y' })).toBe(
      ofrHash(kodachrome),
    );
    expect(ofrHash({ ...kodachrome, sensors: ['X-Trans V'] })).not.toBe(
      ofrHash(kodachrome),
    );
  });
});

describe('ofr validator', () => {
  it('valid doc has no issues', () =>
    expect(validateOfr(kodachrome)).toEqual([]));
  it('ranges + half steps + enums', () => {
    expect(fields({ ...kodachrome, clarity: 9 })).toContain('clarity');
    expect(fields({ ...kodachrome, shadow: 0.3 })).toContain('shadow');
    expect(fields({ ...kodachrome, film_simulation: 'Kodak' })).toContain(
      'film_simulation',
    );
    expect(fields({ ...kodachrome, white_balance: 'Cloudy' })).toContain(
      'white_balance',
    );
  });
  it('omission rules', () => {
    expect(fields({ ...kodachrome, d_range_priority: 'Weak' })).toEqual(
      expect.arrayContaining(['dynamic_range', 'highlight', 'shadow']),
    );
    expect(fields({ ...kodachrome, film_simulation: 'Acros STD' })).toEqual(
      expect.arrayContaining([
        'color',
        'color_chrome_effect',
        'color_chrome_fx_blue',
      ]),
    );
    expect(fields({ ...kodachrome, white_balance: 'Kelvin' })).toContain(
      'wb_kelvin',
    );
    expect(
      validateOfr({ ...kodachrome, white_balance: 'Kelvin', wb_kelvin: 5600 }),
    ).toEqual([]);
    expect(fields({ ...kodachrome, grain_roughness: 'Off' })).toContain(
      'grain_size',
    );
  });
  it('warnings vs errors', () => {
    const issues = validateOfr({ ...kodachrome, name: 'x'.repeat(30), v: 2 });
    expect(issues.find((i) => i.field === 'name')?.severity).toBe('warning');
    expect(issues.find((i) => i.field === 'v')?.severity).toBe('error');
    expect(hasErrors(issues)).toBe(true);
    expect(
      hasErrors(validateOfr({ ...kodachrome, name: 'x'.repeat(30) })),
    ).toBe(false);
  });
  it('missing required', () => {
    expect(fields({ v: 1 })).toEqual(
      expect.arrayContaining([
        'film_simulation',
        'white_balance',
        'd_range_priority',
        'grain_roughness',
      ]),
    );
  });
});
