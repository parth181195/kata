import 'package:test/test.dart';
import 'package:ofr/ofr.dart';

const kodachrome = OfrRecipe(v: 1, name: 'Kodachrome 64', sensors: ['X-Trans IV'], sourceAttribution: 'Fuji X Weekly',
    filmSimulation: 'Classic Chrome', dynamicRange: 'DR400', dRangePriority: 'Off', grainRoughness: 'Weak', grainSize: 'Small',
    colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off', whiteBalance: 'Daylight', whiteBalanceRed: 2, whiteBalanceBlue: -5,
    highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0);

void main() {
  test('README Kodachrome round-trips; hash identical; payload compact', () {
    final code = KataCode.encode(kodachrome);
    expect(code, 'kata1:CC,DR400,WBD/+2-5,H-1,S+0.5,C+2,SH-2,NR-4,GR-WS,CCR-W,CCB-O;n=Kodachrome+64;a=Fuji+X+Weekly;v=xt4');
    expect(code.length, lessThan(120));
    final r = KataCode.decode(code);
    expect(r.warnings, isEmpty);
    expect(r.recipe.name, 'Kodachrome 64');
    expect(r.recipe.sensors, ['X-Trans IV']);
    expect(r.recipe.sourceAttribution, 'Fuji X Weekly');
    expect(OfrHasher.compute(r.recipe), OfrHasher.compute(kodachrome));
    expect(OfrHasher.compute(r.recipe), 'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176');
  });

  test('kelvin + mono extras + exposure comp + source url', () {
    const mono = OfrRecipe(name: 'Mono Push', sensors: ['X-Trans V', 'GFX'], sourceUrl: 'https://example.com/a?b=1',
        filmSimulation: 'Acros Red', dynamicRange: 'DR200', dRangePriority: 'Weak', grainRoughness: 'Strong', grainSize: 'Large',
        whiteBalance: 'Kelvin', wbKelvin: 5800, whiteBalanceRed: 0, whiteBalanceBlue: -3, highlight: 2, shadow: 3, sharpness: 0,
        highIsoNr: -2, clarity: -2, monochromaticColorWarmCool: 2, monochromaticColorMagentaGreen: -1, extra: {'x_exposure_comp': -0.67});
    final code = KataCode.encode(mono);
    expect(code, startsWith('kata1:ACR,DR200,DP-W,WB5800/+0-3,H+2,S+3,NR-2,CL-2,GR-SL,MW+2,MM-1,EC-0.67;n=Mono+Push;v=xt5,gfx;u='));
    final r = KataCode.decode(code).recipe;
    expect(r.whiteBalance, 'Kelvin');
    expect(r.wbKelvin, 5800);
    expect(r.whiteBalanceBlue, -3);
    expect(r.monochromaticColorWarmCool, 2);
    expect(r.extra['x_exposure_comp'], -0.67);
    expect(r.sourceUrl, 'https://example.com/a?b=1');
    expect(OfrHasher.compute(r), OfrHasher.compute(mono));
  });

  test('defaults omitted → tiny code; unknown tokens warn; bad prefix throws; whitespace/newlines tolerated', () {
    const plain = OfrRecipe(filmSimulation: 'Provia', dRangePriority: 'Off', grainRoughness: 'Off', whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0);
    expect(KataCode.encode(plain), 'kata1:PV,WBA');
    final r = KataCode.decode('kata1:PV,WBA,ZZ9,\nH+1;n=Hi+there;q=1');
    expect(r.recipe.highlight, 1);
    expect(r.recipe.name, 'Hi there');
    expect(r.warnings, ['unknown token "ZZ9"', 'unknown meta "q"']);
    expect(() => KataCode.decode('https://kata.parthjansari.dev/kata.apk'), throwsFormatException);
    expect(KataCode.looksLike(' kata1:PV'), isTrue);
    expect(KataCode.looksLike('{"v":1}'), isFalse);
    expect(r.settingsCount, greaterThan(5));
  });
}
