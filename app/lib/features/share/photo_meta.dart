import 'dart:isolate';
import 'dart:typed_data';

import 'package:exif/exif.dart';

/// What a photo remembers about itself. Frames feed on this — the label
/// card's tombstone, the timestamp grid's red cells — and the Photo panel
/// shows it as a data line. RAF imports carry it too: the extracted preview
/// JPEG holds the camera's full EXIF.
class PhotoMeta {
  const PhotoMeta({this.dateTime, this.iso, this.make, this.model, this.fNumber, this.exposure, this.focalMm, this.filmMode});
  final DateTime? dateTime;
  final int? iso;
  final String? make;
  final String? model;
  final double? fNumber;
  final String? exposure; // as shot, e.g. 1/250
  final double? focalMm;
  /// Fujifilm MakerNote film simulation, when the camera wrote one.
  final String? filmMode;

  bool get isEmpty => dateTime == null && iso == null && model == null && fNumber == null && exposure == null;

  /// The mono data line: "X-S20 · ISO 400 · f/2.8 · 1/250 · 23MM · 12/08 18:43"
  String get line {
    final parts = <String>[
      ?model?.toUpperCase(),
      if (iso != null) 'ISO $iso',
      if (fNumber != null) 'f/${fNumber!.toStringAsFixed(fNumber! == fNumber!.roundToDouble() ? 0 : 1)}',
      ?exposure,
      if (focalMm != null) '${focalMm!.round()}MM',
      if (dateTime != null)
        '${dateTime!.day.toString().padLeft(2, '0')}/${dateTime!.month.toString().padLeft(2, '0')} '
            '${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}',
    ];
    return parts.join(' · ');
  }
}

Future<PhotoMeta> readPhotoMeta(Uint8List bytes) => Isolate.run(() => readPhotoMetaSync(bytes));

@pragma('vm:entry-point')
Future<PhotoMeta> readPhotoMetaSync(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    if (tags.isEmpty) return const PhotoMeta();

    String? str(List<String> keys) {
      for (final k in keys) {
        final v = tags[k]?.printable.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    double? ratio(List<String> keys) {
      for (final k in keys) {
        final v = tags[k]?.values;
        if (v is IfdRatios && v.ratios.isNotEmpty) {
          final r = v.ratios.first;
          if (r.denominator != 0) return r.numerator / r.denominator;
        }
      }
      return null;
    }

    DateTime? when;
    final ds = str(['EXIF DateTimeOriginal', 'EXIF DateTimeDigitized', 'Image DateTime']);
    if (ds != null) {
      // EXIF format: 2026:08:12 18:43:07
      final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(ds);
      if (m != null) {
        when = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6]!));
      }
    }

    final isoStr = str(['EXIF ISOSpeedRatings', 'EXIF PhotographicSensitivity']);
    final iso = isoStr == null ? null : int.tryParse(RegExp(r'\d+').firstMatch(isoStr)?.group(0) ?? '');

    var exposure = str(['EXIF ExposureTime']);
    if (exposure != null && !exposure.contains('/')) {
      final secs = double.tryParse(exposure);
      if (secs != null && secs >= 0.25) exposure = '${secs.toStringAsFixed(secs == secs.roundToDouble() ? 0 : 1)}"';
    }

    int? rawInt(String key) {
      final v = tags[key]?.printable;
      if (v == null) return null;
      return int.tryParse(RegExp(r'-?\d+').firstMatch(v)?.group(0) ?? '');
    }

    return PhotoMeta(
      dateTime: when,
      iso: iso,
      make: str(['Image Make']),
      model: str(['Image Model']),
      fNumber: ratio(['EXIF FNumber']),
      exposure: exposure,
      focalMm: ratio(['EXIF FocalLength']),
      // the exif package decodes Fuji's MakerNote but doesn't name these tags
      filmMode: fujiFilmSimName(rawInt('MakerNote Tag 0x1401'), tags['MakerNote Saturation']?.printable),
    );
  } catch (_) {
    return const PhotoMeta();
  }
}


/// Fujifilm names for MakerNote FilmMode (0x1401) — the monochrome looks live
/// in the Saturation tag (0x1003) instead, which wins when it says B&W. The
/// exif package names the values it knows ("None (B&W)") and prints raw
/// numbers for the ones its table predates (ACROS is 0x4C0+), so both forms
/// are mapped. Value tables per exiftool's FujiFilm module.
String? fujiFilmSimName(int? filmMode, String? saturation) {
  if (saturation != null) {
    const monoNames = {
      'None (B&W)': 'MONOCHROME',
      'B&W Red Filter': 'MONOCHROME+R',
      'B&W Yellow Filter': 'MONOCHROME+Y',
      'B&W Green Filter': 'MONOCHROME+G',
      'B&W Sepia': 'SEPIA',
    };
    const monoValues = {
      0x300: 'MONOCHROME',
      0x301: 'MONOCHROME+R',
      0x302: 'MONOCHROME+Y',
      0x303: 'MONOCHROME+G',
      0x310: 'SEPIA',
      0x4C0: 'ACROS',
      0x4C1: 'ACROS+R',
      0x4C2: 'ACROS+Y',
      0x4C3: 'ACROS+G',
    };
    final named = monoNames[saturation.trim()];
    if (named != null) return named;
    final raw = int.tryParse(saturation.trim());
    final mapped = monoValues[raw];
    if (mapped != null) return mapped;
  }
  const sims = {
    0x000: 'PROVIA',
    0x120: 'ASTIA',
    0x200: 'VELVIA',
    0x400: 'VELVIA',
    0x500: 'PRO NEG. STD',
    0x501: 'PRO NEG. HI',
    0x600: 'CLASSIC CHROME',
    0x700: 'ETERNA',
    0x800: 'CLASSIC NEG',
    0x900: 'BLEACH BYPASS',
    0xA00: 'NOSTALGIC NEG',
    0xB00: 'REALA ACE',
  };
  return sims[filmMode];
}
