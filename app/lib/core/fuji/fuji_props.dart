// Fujifilm preset-protocol enums and encodings (see docs/fuji-usb-research.md §3–4).

/// D190 value meaning "DR Auto".
const kDrAuto = 0xFFFF;

class FilmSim {
  static const provia = 1, velvia = 2, astia = 3, proNegHi = 4, proNegStd = 5;
  static const monochrome = 6, monochromeYe = 7, monochromeR = 8, monochromeG = 9, sepia = 10;
  static const classicChrome = 11, acros = 12, acrosYe = 13, acrosR = 14, acrosG = 15;
  static const eterna = 16, classicNeg = 17, eternaBleach = 18, nostalgicNeg = 19, realaAce = 20;

  static const monoSet = {monochrome, monochromeYe, monochromeR, monochromeG, sepia, acros, acrosYe, acrosR, acrosG};
  static bool isMono(int code) => monoSet.contains(code);

  static const labels = <int, String>{
    provia: 'Provia',
    velvia: 'Velvia',
    astia: 'Astia',
    proNegHi: 'Pro Neg. Hi',
    proNegStd: 'Pro Neg. Std',
    monochrome: 'Monochrome',
    monochromeYe: 'Monochrome+Ye',
    monochromeR: 'Monochrome+R',
    monochromeG: 'Monochrome+G',
    sepia: 'Sepia',
    classicChrome: 'Classic Chrome',
    acros: 'Acros',
    acrosYe: 'Acros+Ye',
    acrosR: 'Acros+R',
    acrosG: 'Acros+G',
    eterna: 'Eterna',
    classicNeg: 'Classic Neg',
    eternaBleach: 'Eterna Bleach Bypass',
    nostalgicNeg: 'Nostalgic Neg',
    realaAce: 'Reala Ace',
  };

  static const abbr = <int, String>{
    provia: 'PRO',
    velvia: 'VEL',
    astia: 'AST',
    proNegHi: 'PNH',
    proNegStd: 'PNS',
    monochrome: 'MONO',
    monochromeYe: 'M+Y',
    monochromeR: 'M+R',
    monochromeG: 'M+G',
    sepia: 'SEP',
    classicChrome: 'CC',
    acros: 'ACR',
    acrosYe: 'A+Y',
    acrosR: 'A+R',
    acrosG: 'A+G',
    eterna: 'ETR',
    classicNeg: 'CN',
    eternaBleach: 'EBB',
    nostalgicNeg: 'NN',
    realaAce: 'RA',
  };
}

class WbMode {
  static const asShot = 0x0000, auto = 0x0002, daylight = 0x0004, incandescent = 0x0006, underwater = 0x0008;
  static const fluorescent1 = 0x8001, fluorescent2 = 0x8002, fluorescent3 = 0x8003, shade = 0x8006, colorTemp = 0x8007;
  static const custom1 = 0x8008, custom2 = 0x8009, custom3 = 0x800A; // from libgphoto2, unverified on presets
  static const whitePriority = 0x8020; // unverified guess
  static const ambiencePriority = 0x8021;

  static const labels = <int, String>{
    asShot: 'As Shot',
    auto: 'Auto',
    daylight: 'Daylight',
    incandescent: 'Incandescent',
    underwater: 'Underwater',
    fluorescent1: 'Fluorescent 1',
    fluorescent2: 'Fluorescent 2',
    fluorescent3: 'Fluorescent 3',
    shade: 'Shade',
    colorTemp: 'Color Temp',
    custom1: 'Custom 1',
    custom2: 'Custom 2',
    custom3: 'Custom 3',
    whitePriority: 'Auto (white priority)',
    ambiencePriority: 'Auto (ambience priority)',
  };
}

class GrainEnum {
  static const off = 1, weakSmall = 2, strongSmall = 3, weakLarge = 4, strongLarge = 5;
  static const labels = <int, String>{
    off: 'Off',
    weakSmall: 'Weak/Small',
    strongSmall: 'Strong/Small',
    weakLarge: 'Weak/Large',
    strongLarge: 'Strong/Large',
  };
}

class Effect {
  static const off = 1, weak = 2, strong = 3;
  static const labels = <int, String>{off: 'Off', weak: 'Weak', strong: 'Strong'};
}

/// High ISO NR: UI value (-4..+4) -> raw u16.
const nrEncode = <int, int>{
  -4: 0x8000, -3: 0x7000, -2: 0x4000, -1: 0x3000, 0: 0x2000, 1: 0x1000, 2: 0x0000, 3: 0x6000, 4: 0x5000,
};

/// Raw u16 -> UI value.
const nrDecode = <int, int>{
  0x8000: -4, 0x7000: -3, 0x4000: -2, 0x3000: -1, 0x2000: 0, 0x1000: 1, 0x0000: 2, 0x6000: 3, 0x5000: 4,
};

/// Props whose bytes are copied from the existing slot, never synthesized.
const rawPassthroughProps = {0xD18E, 0xD18F, 0xD191, 0xD1A3, 0xD1A4, 0xD1A5};

/// X RAW Studio write order (conditional props included; PresetWriter drops the ones that don't apply).
const presetWriteOrder = <int>[
  0xD18D, 0xD18E, 0xD18F, 0xD190, 0xD191, 0xD192, 0xD193, 0xD194, 0xD195, 0xD196, 0xD197, 0xD198, //
  0xD199, 0xD19C, 0xD19A, 0xD19B, 0xD19D, 0xD19E, 0xD19F, 0xD1A0, 0xD1A1, 0xD1A2, 0xD1A3, 0xD1A4, 0xD1A5,
];
