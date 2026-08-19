import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum KataStatus { connected, disconnected, offline, noCamera }

class KataStatusPill extends StatelessWidget {
  const KataStatusPill(this.status, {super.key, this.label});
  final KataStatus status;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final filled = status == KataStatus.connected;
    final text = label ??
        switch (status) {
          KataStatus.connected => 'CONNECTED',
          KataStatus.disconnected => 'DISCONNECTED',
          KataStatus.offline => 'OFFLINE',
          KataStatus.noCamera => 'NO CAMERA',
        };
    final dot = switch (status) {
      KataStatus.connected => BoxDecoration(shape: BoxShape.circle, color: p.bg),
      KataStatus.offline => BoxDecoration(shape: BoxShape.circle, color: p.muted),
      _ => BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.muted, width: 1.5)),
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: filled ? p.fg : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: filled ? null : Border.all(color: p.hairline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: dot),
        const SizedBox(width: 8),
        Text(text, style: KataType.monoStyle(size: 10, weight: FontWeight.w500, color: filled ? p.bg : p.muted)),
      ]),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 15});
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.fg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('✓', style: TextStyle(fontFamily: KataType.body, fontSize: size * 0.6, fontWeight: FontWeight.w600, color: p.bg, height: 1)),
    );
  }
}
