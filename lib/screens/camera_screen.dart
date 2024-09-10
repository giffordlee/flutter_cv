import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late List<CameraDescription> _cameras;
  late Future<void> _initializeControllerFuture;
  late CameraController controller;
  late List<String> labels;
  final String _model = "yolo";
  List<dynamic> recognitions = [];

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = initializeCameras();
    loadModel();
  }

  Future loadModel() async {
    Tflite.close();
    try {
      String res;
      switch (_model) {
        case "yolo":
          res = (await Tflite.loadModel(
            model: "assets/models/yolov2_tiny.tflite",
            labels: "assets/models/yolov2_tiny.txt",
            // useGpuDelegate: true,
          ))!;
          break;
        case "ssd":
          res = (await Tflite.loadModel(
            model: "assets/models/ssd_mobilenet.tflite",
            labels: "assets/models/ssd_mobilenet.txt",
            // useGpuDelegate: true,
          ))!;
          break;
        case "deeplab":
          res = (await Tflite.loadModel(
            model: "assets/models/deeplabv3_257_mv_gpu.tflite",
            labels: "assets/models/deeplabv3_257_mv_gpu.txt",
            // useGpuDelegate: true,
          ))!;
          break;
        case "posenet":
          res = (await Tflite.loadModel(
            model:
                "assets/models/posenet_mv1_075_float_from_checkpoints.tflite",
            // useGpuDelegate: true,
          ))!;
          break;
        default:
          res = (await Tflite.loadModel(
            model: "assets/models/mobilenet_v1_1.0_224.tflite",
            labels: "assets/models/mobilenet_v1_1.0_224.txt",
            // useGpuDelegate: true,
          ))!;
      }
      print(res);
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  Future<void> initializeCameras() async {
    _cameras = await availableCameras();
    controller = CameraController(_cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    bool flag = true;
    controller.startImageStream((CameraImage img) async {
      if (flag) {
        List<dynamic>? recognitions = await Tflite.detectObjectOnFrame(
            bytesList: img.planes.map((plane) {
              return plane.bytes;
            }).toList(), // required
            model: "YOLO",
            imageHeight: img.height,
            imageWidth: img.width,
            imageMean: 0, // defaults to 127.5
            imageStd: 255.0, // defaults to 127.5
            threshold: 0.3, // defaults to 0.1
            numResultsPerClass: 2, // defaults to 5
            blockSize: 32, // defaults to 32
            numBoxesPerBlock: 5, // defaults to 5
            asynch: true // defaults to true
            );
        var highestConfidence = recognitions!.reduce((curr, next) =>
            curr['confidenceInClass'] > next['confidenceInClass']
                ? curr
                : next);
        print(recognitions);
        print(highestConfidence);
        setState(() {
          this.recognitions = [highestConfidence];
        });
        // flag = false;
      }
    });
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
            return Stack(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                        width: 100, // the actual width is not important here
                        child: CameraPreview(controller)),
                  ),
                ),
                ...recognitions.map((recog) {
                  return Positioned(
                    left:
                        recog['rect']['x'] * MediaQuery.of(context).size.width,
                    top:
                        recog['rect']['y'] * MediaQuery.of(context).size.height,
                    width:
                        recog['rect']['w'] * MediaQuery.of(context).size.width,
                    height:
                        recog['rect']['h'] * MediaQuery.of(context).size.height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        "${recog['detectedClass']} ${(recog['confidenceInClass'] * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          background: Paint()..color = Colors.red,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
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
