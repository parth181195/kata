import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ofrHash, validateOfr } from '../../src/ofr';
import { parseFxwPost } from './scrape-fxw';

const fixture = (n: string) => readFileSync(join(__dirname, 'fixtures', n), 'utf8');

describe('Fuji X Weekly parser', () => {
  it('parses the X100V Kodachrome 64 post', () => {
    const r = parseFxwPost(fixture('fxw-kodachrome-x100v.html'), 'https://fujixweekly.com/2020/05/27/my-fujifilm-x100v-kodachrome-64-film-simulation-recipe/');
    if ('error' in r) throw new Error(r.error);
    expect(r.ofr).toMatchObject({
      v: 1,
      name: 'Kodachrome 64',
      film_simulation: 'Classic Chrome',
      dynamic_range: 'DR200',
      d_range_priority: 'Off',
      highlight: 0,
      shadow: 0,
      color: 2,
      high_iso_nr: -4,
      sharpness: 1,
      clarity: 3,
      grain_roughness: 'Weak',
      grain_size: 'Small',
      color_chrome_effect: 'Strong',
      color_chrome_fx_blue: 'Weak',
      white_balance: 'Daylight',
      white_balance_red: 2,
      white_balance_blue: -5,
      source_attribution: 'Fuji X Weekly',
      sensors: ['X-Trans IV'],
    });
    expect(r.ofr.x_exposure_comp).toBe(0);
    expect(validateOfr(r.ofr)).toEqual([]);
    expect(ofrHash(r.ofr)).toMatch(/^[0-9a-f]{64}$/);
    expect(r.imageUrls).toEqual([
      'https://i0.wp.com/fujixweekly.com/wp-content/uploads/2020/05/49939037433_7fbe4d17c1_c.jpg',
      'https://i0.wp.com/fujixweekly.com/wp-content/uploads/2020/05/49939817307_c5b9b63cc2_c.jpg',
    ]);
  });

  it('handles mono + kelvin + DRP lines and rejects unknown film sims', () => {
    const html = (sim: string) => `<html><body><h1 class="entry-title">Fujifilm X-T5 Night Acros Film Simulation Recipe</h1>
      <div class="entry-content"><p>${sim}<br>Dynamic Range: DR-Auto<br>Highlight: +1.5<br>Shadow: -1<br>Sharpening: -2<br>Noise Reduction: -4<br>Clarity: 0<br>
      Grain Effect: Strong, Large<br>Monochromatic Color: +2 WC &amp; -1 MG<br>White Balance: 4300K, +1 Red &amp; -3 Blue<br>Color: +2<br>Exposure Compensation: +1/3 to +1</p></div>
      <footer><a rel="tag" href="#">Fujifilm X-T5</a></footer></body></html>`;
    const r = parseFxwPost(html('Acros+R'), 'https://x/y');
    if ('error' in r) throw new Error(r.error);
    expect(r.ofr).toMatchObject({ name: 'Night Acros', film_simulation: 'Acros Red', dynamic_range: 'DR-Auto', white_balance: 'Kelvin', wb_kelvin: 4300, white_balance_red: 1, white_balance_blue: -3,
      grain_roughness: 'Strong', grain_size: 'Large', monochromatic_color_warm_cool: 2, monochromatic_color_magenta_green: -1, highlight: 1.5, shadow: -1, sensors: ['X-Trans V'], x_exposure_comp: 0.33 });
    expect(r.ofr.color).toBeUndefined();
    expect(validateOfr(r.ofr)).toEqual([]);
    expect(parseFxwPost(html('Kodak Portra'), 'https://x/y')).toEqual({ error: 'film simulation not recognised' });
  });
});
