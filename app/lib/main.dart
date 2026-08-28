import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship with the app: a frame that needs the network to render is a
  // frame that fails on a plane.
  runApp(const ProviderScope(child: KataApp()));
}
