// OFR v1 reference lists (https://github.com/gosku/open-fuji-recipe) and the Fujifilm
// camera codes they correspond to (film simulation / WB values as used over PTP and in RAF EXIF).

class OfrEnums {
  /// OFR film simulation name -> Fujifilm film-sim code.
  static const filmSimToCode = <String, int>{
    'Provia': 1,
    'Velvia': 2,
    'Astia': 3,
    'Classic Chrome': 11,
    'Pro Neg. Hi': 4,
    'Pro Neg. Std': 5,
    'Classic Negative': 17,
    'Eterna': 16,
    'Eterna Bleach Bypass': 18,
    'Nostalgic Negative': 19,
    'Reala Ace': 20,
    'Acros STD': 12,
    'Acros Yellow': 13,
    'Acros Red': 14,
    'Acros Green': 15,
    'Monochrome STD': 6,
    'Monochrome Yellow': 7,
    'Monochrome Red': 8,
    'Monochrome Green': 9,
    'Sepia': 10,
  };
  static final codeToFilmSim = <int, String>{for (final e in filmSimToCode.entries) e.value: e.key};
  static final filmSims = filmSimToCode.keys.toList(growable: false);

  static const monoFilmSims = {
    'Acros STD', 'Acros Yellow', 'Acros Red', 'Acros Green',
    'Monochrome STD', 'Monochrome Yellow', 'Monochrome Red', 'Monochrome Green', 'Sepia',
  };
  static bool isMonoName(String name) => monoFilmSims.contains(name);

  /// OFR white balance name -> Fujifilm WB code. 0x8020 (white priority) and 0x8008..A (custom) are unverified.
  static const wbToCode = <String, int>{
    'Auto': 0x0002,
    'Auto (white priority)': 0x8020,
    'Auto (ambience priority)': 0x8021,
    'Daylight': 0x0004,
    'Shade': 0x8006,
    'Incandescent': 0x0006,
    'Fluorescent 1': 0x8001,
    'Fluorescent 2': 0x8002,
    'Fluorescent 3': 0x8003,
    'Kelvin': 0x8007,
    'Underwater': 0x0008,
    'Custom 1': 0x8008,
    'Custom 2': 0x8009,
    'Custom 3': 0x800A,
  };
  static final codeToWb = <int, String>{for (final e in wbToCode.entries) e.value: e.key};
  static final wbModes = wbToCode.keys.toList(growable: false);

  static const sensors = [
    'X-Trans I', 'X-Trans II', 'X-Trans III', 'X-Trans IV', 'X-Trans V', 'GFX', 'Bayer', 'EXR-CMOS', 'Full Spectrum',
  ];
  static const dynamicRanges = ['DR100', 'DR200', 'DR400', 'DR-Auto'];
  static const dRangePriorities = ['Off', 'Auto', 'Weak', 'Strong'];
  static const grainRoughness = ['Off', 'Weak', 'Strong'];
  static const grainSizes = ['Small', 'Large'];
  static const effects = ['Off', 'Weak', 'Strong'];
}
