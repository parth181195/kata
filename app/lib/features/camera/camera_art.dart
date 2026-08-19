import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';

/// Line art for a body: `assets/cameras/<slug>.svg` if bundled, else `generic.svg`, else a hatched placeholder.
class CameraArt extends StatelessWidget {
  const CameraArt({super.key, this.slug, this.height = 158, this.radius = 18, this.caption});
  final String? slug;
  final double height;
  final double radius;
  final String? caption;

  static Future<Set<String>>? _bundled;
  static Future<Set<String>> bundledSlugs() => _bundled ??= AssetManifest.loadFromAssetBundle(rootBundle).then(
    (m) => m.listAssets().where((a) => a.startsWith('assets/cameras/') && a.endsWith('.svg')).map((a) => a.substring('assets/cameras/'.length, a.length - 4)).toSet(),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return FutureBuilder<Set<String>>(
      future: bundledSlugs(),
      builder: (context, snap) {
        final have = snap.data ?? const <String>{};
        final file = slug != null && have.contains(slug) ? slug : (have.contains('generic') ? 'generic' : null);
        return Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), border: Border.all(color: p.hairline)),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SvgPicture.asset('assets/cameras/$file.svg', colorFilter: ColorFilter.mode(p.fg, BlendMode.srcIn), fit: BoxFit.contain, semanticsLabel: slug),
                )
              : CustomPaint(
                  painter: HatchPainter(p.surface),
                  child: Center(
                    child: Text(
                      (caption ?? (slug == null ? 'LINE ART · MIRRORLESS BODY' : 'LINE ART · ${slug!.toUpperCase()}')),
                      textAlign: TextAlign.center,
                      style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.1, height: 1.6),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// 45° hatch used behind placeholders.
class HatchPainter extends CustomPainter {
  HatchPainter(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (var x = -s.height; x < s.width; x += 10) {
      c.drawLine(Offset(x, 0), Offset(x + s.height, s.height), p);
    }
  }

  @override
  bool shouldRepaint(HatchPainter o) => o.color != color;
}

/// Known-body lookup for whatever the camera reported as its model name.
KnownBody? knownBodyFor(String? model) => model == null ? null : KnownBody.forModel(model);
