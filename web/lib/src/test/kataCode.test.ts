import { describe, expect, it } from 'vitest';
import { encodeKataCode } from '../kataCode';

// vectors copied from packages/ofr/test/kata_code_test.dart — keep byte-identical
describe('kataCode encode (TS port)', () => {
  it('README Kodachrome matches the Dart codec', () => {
    expect(encodeKataCode({
      name: 'Kodachrome 64', sensors: ['X-Trans IV'], source_attribution: 'Fuji X Weekly',
      film_simulation: 'Classic Chrome', dynamic_range: 'DR400', d_range_priority: 'Off', grain_roughness: 'Weak', grain_size: 'Small',
      color_chrome_effect: 'Weak', color_chrome_fx_blue: 'Off', white_balance: 'Daylight', white_balance_red: 2, white_balance_blue: -5,
      highlight: -1, shadow: 0.5, color: 2, sharpness: -2, high_iso_nr: -4, clarity: 0,
    })).toBe('kata1:CC,DR400,WBD/+2-5,HL-1,SD+0.5,CO+2,SH-2,NR-4,GR-WS,CCR-W,CCB-O;n=Kodachrome+64;a=Fuji+X+Weekly;v=xt4');
  });
  it('kelvin + mono extras', () => {
    expect(encodeKataCode({
      name: 'Mono Push', sensors: ['X-Trans V', 'GFX'], source_url: 'https://example.com/a?b=1',
      film_simulation: 'Acros Red', dynamic_range: 'DR200', d_range_priority: 'Weak', grain_roughness: 'Strong', grain_size: 'Large',
      white_balance: 'Kelvin', wb_kelvin: 5800, white_balance_red: 0, white_balance_blue: -3, highlight: 2, shadow: 3,
      sharpness: 0, high_iso_nr: -2, clarity: -2, monochromatic_color_warm_cool: 2, monochromatic_color_magenta_green: -1,
      x_exposure_comp: -0.67,
    } as never)).toMatch(/^kata1:ACR,DR200,DP-W,WB5800\/\+0-3,HL\+2,SD\+3,NR-2,CL-2,GR-SL,MW\+2,MM-1,EC-0\.67;n=Mono\+Push;v=xt5,gfx;u=/);
  });
  it('defaults omitted', () => {
    expect(encodeKataCode({ film_simulation: 'Provia', d_range_priority: 'Off', grain_roughness: 'Off', white_balance: 'Auto', white_balance_red: 0, white_balance_blue: 0, sharpness: 0, high_iso_nr: 0, clarity: 0 })).toBe('kata1:PV,WBA');
  });
});
