import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

  final rearCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
  );

  runApp(MyApp(camera: frontCamera, rearCamera: rearCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  final CameraDescription rearCamera;

  const MyApp({super.key, required this.camera, required this.rearCamera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraPage(camera: camera, rearCamera: rearCamera),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  final CameraDescription rearCamera;

  const CameraPage({super.key, required this.camera, required this.rearCamera});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController controller;
  bool isRateCameraActive = false;

  @override
  void initState() {
    super.initState();

    controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void changeCamera() {
    controller = CameraController(
      isRateCameraActive ? widget.rearCamera : widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          isRateCameraActive = !isRateCameraActive;
        });
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Scaffold(
        body: Column(
          children: [
            CircularProgressIndicator(),
            ElevatedButton(
              onPressed: changeCamera,
              child: Text("Change Camera"),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          CameraPreview(controller),
          SizedBox(height: 16),
          ElevatedButton(onPressed: changeCamera, child: Text("Change Camera")),
        ],
      ),
    );
  }
}
