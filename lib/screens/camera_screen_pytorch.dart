import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pytorch_lite/lib.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:image/image.dart' as img;

class CameraScreenPytorch extends StatefulWidget {
  const CameraScreenPytorch({super.key});

  @override
  State<CameraScreenPytorch> createState() => _CameraScreenPytorchState();
}

class _CameraScreenPytorchState extends State<CameraScreenPytorch> {
  late List<CameraDescription> _cameras;
  late Future<void> _initializeControllerFuture;
  late CameraController controller;
  late List<String> labels;
  ModelObjectDetection? classificationModel;
  List<dynamic> recognitions = [];

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = initializeCameras();
    loadModel();
  }

  Future<void> loadModel() async {
    classificationModel = await PytorchLite.loadObjectDetectionModel(
        "assets/models/yolov8n.torchscript", 80, 640, 640,
        labelPath: "assets/models/labels_objectDetection_Coco.txt",
        objectDetectionModelType: ObjectDetectionModelType.yolov8);
  }

  Future<void> initializeCameras() async {
    _cameras = await availableCameras();
    controller = CameraController(_cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    bool flag = true;
    controller.startImageStream((CameraImage curr) async {
      if (flag && classificationModel != null) {
        // Prevent processing another frame until the current one is done
        flag = false;
        try {
          final prediction =
              await classificationModel!.getCameraImagePrediction(curr);
          print(
              "label: ${prediction[0].className},score: ${prediction[0].score}, rect: ${prediction[0].rect}");
          setState(() {
            recognitions = [
              {
                'detectedClass': prediction[0].className,
                'confidenceInClass': prediction[0].score,
                'rect': {
                  'x': prediction[0].rect.left,
                  'y': prediction[0].rect.top,
                  'w': prediction[0].rect.width,
                  'h': prediction[0].rect.height
                }
              }
            ];
          });
        } catch (e) {
          print("Error: $e");
          setState(() {
            recognitions = [];
          });
        } finally {
          await Future.delayed(Duration(milliseconds: 100));
          flag = true;
        }
      }
    });
  }

  img.Image convertToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];

    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      bytesOffset: 28,
      order: img.ChannelOrder.bgra,
    );
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
