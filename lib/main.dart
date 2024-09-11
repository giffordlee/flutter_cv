import 'package:flutter/material.dart';
import 'package:flutter_cv/screens/camera_screen_tflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: CameraScreenTFLite(),
    );
  }
}
