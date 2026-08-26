import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A frame speaks in a voice, not in a font. Each voice pairs three roles —
/// display (the numeral, the big mark), text (the country line, the caption)
/// and data (dates, codes) — so an object can be set entirely from one choice,
/// and two objects rolled the same way still sound different.
enum VoiceId { postOffice, bureau, deco, civic }

class Voice {
  const Voice(this.id, this.display, this.text, this.data, {this.displayWeight = FontWeight.w700, this.displayTracking = 0});

  final VoiceId id;
  final String display, text, data;
  final FontWeight displayWeight;

  /// Fraction of the font size, applied as letter spacing on display type.
  final double displayTracking;

  TextStyle displayStyle(double size, Color c) => GoogleFonts.getFont(display,
      fontSize: size, fontWeight: displayWeight, color: c, height: 1, letterSpacing: size * displayTracking);

  TextStyle textStyle(double size, Color c, {FontWeight weight = FontWeight.w500, double tracking = 0.12}) =>
      GoogleFonts.getFont(text, fontSize: size, fontWeight: weight, color: c, height: 1.1, letterSpacing: size * tracking);

  TextStyle dataStyle(double size, Color c) =>
      GoogleFonts.getFont(data, fontSize: size, fontWeight: FontWeight.w500, color: c, height: 1);
}

const kVoices = <VoiceId, Voice>{
  VoiceId.postOffice: Voice(VoiceId.postOffice, 'Oswald', 'Barlow Condensed', 'Space Mono', displayTracking: -0.03),
  VoiceId.bureau: Voice(VoiceId.bureau, 'Archivo Black', 'IBM Plex Sans', 'IBM Plex Mono'),
  VoiceId.deco: Voice(VoiceId.deco, 'Playfair Display', 'Cormorant Garamond', 'Courier Prime', displayWeight: FontWeight.w900),
  VoiceId.civic: Voice(VoiceId.civic, 'Bebas Neue', 'Work Sans', 'Roboto Mono'),
};

/// How likely each allowed voice is for this shot. Weighting, never forcing:
/// every allowed voice keeps a floor of 1, so a shuffle can still surprise.
Map<VoiceId, double> voiceWeights({required String? filmSim, required int? iso, required Set<VoiceId> allowed}) {
  final sim = (filmSim ?? '').toUpperCase();
  bool has(List<String> keys) => keys.any(sim.contains);

  final w = {for (final id in allowed) id: 1.0};
  void bump(VoiceId id, double by) {
    if (w.containsKey(id)) w[id] = w[id]! + by;
  }

  if (has(['ACROS', 'MONOCHROME', 'SEPIA'])) {
    bump(VoiceId.deco, 2.5); // high-contrast serif suits black and white
    bump(VoiceId.bureau, 0.5);
  }
  if (has(['CLASSIC NEG', 'NOSTALGIC', 'ETERNA'])) {
    bump(VoiceId.postOffice, 2.0); // warm mid-century
  }
  if (has(['CLASSIC CHROME', 'PROVIA', 'REALA'])) {
    bump(VoiceId.bureau, 2.0); // neutral, institutional
  }
  if (has(['VELVIA'])) {
    bump(VoiceId.civic, 2.0); // condensed poster
  }
  if ((iso ?? 0) >= 3200) {
    bump(VoiceId.civic, 1.0); // a rough shot wants a heavier display
    bump(VoiceId.bureau, 0.5);
  }
  return w;
}
