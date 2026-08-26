import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship with the app: a frame that needs the network to render is a
  // frame that fails on a plane.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: KataApp()));
}
