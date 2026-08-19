import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The Kata Code QR: ECC M, 4-module quiet zone, always monochrome (inversion allowed, no logo, never tinted).
class KataCodeQr extends StatelessWidget {
  const KataCodeQr({super.key, required this.payload, required this.size, this.inverted = false});
  final String payload;
  final double size;
  /// White modules on black (for dark cards). Default black on white.
  final bool inverted;
  @override
  Widget build(BuildContext context) {
    final fg = inverted ? Colors.white : Colors.black;
    final bg = inverted ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      color: bg,
      // QrImageView pads ~ its own quiet zone via `padding`; 4 modules ≈ size / (modules + 8) * 4 — approximate with size*0.08
      padding: EdgeInsets.all(size * 0.08),
      child: QrImageView(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        padding: EdgeInsets.zero,
        backgroundColor: bg,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fg),
        dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: fg),
        gapless: true,
        semanticsLabel: 'Kata Code',
      ),
    );
  }
}
