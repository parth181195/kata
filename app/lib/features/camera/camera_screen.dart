import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Text('CAMERA', style: KataType.displayStyle(size: 24, color: context.kata.fg)))));
}
