import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

//input tensors: [Tensor{_tensor: Pointer: address=0x1103d4000, name: inputs_0, type: float32, shape: [1, 640, 640, 3], data: 4915200}]
// output tensors: [Tensor{_tensor: Pointer: address=0x11036ebd0, name: Identity, type: float32, shape: [1, 84, 8400], data: 2822400}]
class _CameraScreenState extends State<CameraScreen> {
  late List<CameraDescription> _cameras;
  late Future<void> _initializeControllerFuture;
  late CameraController controller;
  late List<String> labels;
  late Interpreter interpreter;
  final output = List<num>.filled(1 * 84 * 8400, 0).reshape([1, 84, 8400]);

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = initializeCameras();
    loadModel();
  }

  List<int> getMatrixShape(List<dynamic> matrix) {
    List<int> shape = [];
    dynamic currentLevel = matrix;

    while (currentLevel is List) {
      shape.add(currentLevel.length);
      currentLevel = currentLevel.isNotEmpty ? currentLevel[0] : null;
    }

    return shape;
  }

  Future<void> initializeCameras() async {
    _cameras = await availableCameras();
    controller = CameraController(_cameras[0], ResolutionPreset.low);
    await controller.initialize();
    bool show = true;
    controller.startImageStream((CameraImage image) {
      if (show) {
        final output =
            List<num>.filled(1 * 84 * 8400, 0).reshape([1, 84, 8400]);
        final input = _preProcess(imageFromCameraImage(image)!);
        int predictionTimeStart = DateTime.now().millisecondsSinceEpoch;
        interpreter.run([input], output);
        int predictionTime =
            DateTime.now().millisecondsSinceEpoch - predictionTimeStart;
        print('Prediction time: $predictionTime ms');
        print(output[0].length);
// Assuming the output is a 2D array with shape [1, num_labels]
        // List<num> probabilities = output[0];
        // int maxIndex = probabilities
        //     .indexWhere((prob) => prob == probabilities.reduce(max));
        // String label =
        //     labels[maxIndex]; // 'labels' should be a predefined list of labels

        // print('Label: $label, Probability: ${probabilities[maxIndex]}');
        show = false;
      }

      // interpreter.run(input, output);
      // print(output);
    });
  }

  Map<String, dynamic> getHighestProbPrediction(List<num> output) {
    const int numBoxes = 8400;
    const int numClasses = 79;
    double highestConfidence = 0.0;
    Map<String, dynamic> highestProbPrediction = {};

    for (int i = 0; i < numBoxes; i++) {
      int offset = i * 84;
      double confidence = output[offset + 4].toDouble();

      if (confidence > highestConfidence) {
        highestConfidence = confidence;
        double xMin = output[offset].toDouble();
        double yMin = output[offset + 1].toDouble();
        double xMax = output[offset + 2].toDouble();
        double yMax = output[offset + 3].toDouble();

        List<double> classScores = output
            .sublist(offset + 5, offset + 5 + numClasses)
            .map((e) => e.toDouble())
            .toList();
        int classIndex =
            classScores.indexWhere((score) => score == classScores.reduce(max));
        double classScore = classScores[classIndex];

        highestProbPrediction = {
          'boundingBox': [xMin, yMin, xMax, yMax],
          'confidence': confidence,
          'classIndex': classIndex,
          'classScore': classScore,
        };
      }
    }

    return highestProbPrediction;
  }

  // CameraImage BGRA8888 -> PNG
// Color
  imglib.Image imageFromBGRA8888(CameraImage image) {
    return imglib.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: imglib.ChannelOrder.bgra,
    );
  }

// CameraImage YUV420_888 -> PNG -> Image (compresion:0, filter: none)
// Black
  imglib.Image imageFromYUV420(CameraImage image) {
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 0;
    final img = imglib.Image(width: image.width, height: image.height);
    for (final p in img) {
      final x = p.x;
      final y = p.y;
      final uvIndex =
          uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final index = y * uvRowStride +
          x; // Use the row stride instead of the image width as some devices pad the image data, and in those cases the image width != bytesPerRow. Using width will give you a distored image.
      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];
      p.r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255).toInt();
      p.g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255)
          .toInt();
      p.b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255).toInt();
    }

    return img;
  }

  imglib.Image? imageFromCameraImage(CameraImage image) {
    try {
      imglib.Image img;
      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          img = imageFromYUV420(image);
          break;
        case ImageFormatGroup.bgra8888:
          img = imageFromBGRA8888(image);
          break;
        default:
          return null;
      }
      return img;
    } catch (e) {
      //print(">>>>>>>>>>>> ERROR:" + e.toString());
    }
    return null;
  }

  // yolov8 requires input normalized between 0 and 1
  List<List<List<num>>> convertImageToMatrix(imglib.Image image) {
    return List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.rNormalized, pixel.gNormalized, pixel.bNormalized];
        },
      ),
    );
  }

  List<List<List<num>>> _preProcess(imglib.Image image) {
    final imgResized = imglib.copyResize(image, width: 640, height: 640);

    return convertImageToMatrix(imgResized);
  }

  loadModel() async {
    interpreter =
        await Interpreter.fromAsset('assets/models/yolov8n_float16.tflite');
    print("input tensors: ${interpreter.getInputTensors()}");
    print("output tensors: ${interpreter.getOutputTensors()}");
    labels = await _loadLabels('assets/models/labels.txt');
  }

  Future<List<String>> _loadLabels(String labelsPath) async {
    final labelsData = await rootBundle.loadString(labelsPath);
    return labelsData.split('\n');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: 100, // the actual width is not important here
                    child: CameraPreview(controller)),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
