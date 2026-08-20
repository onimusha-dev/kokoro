import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'services/camera/camera_service.dart';
import 'services/websocket/websocket_server.dart';
import 'ui/camera_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

  // Create independent services
  final cameraService = CameraService();
  final server = WebSocketServer(cameraService);

  // Initialize camera
  await cameraService.initialize(frontCamera);

  // Start server
  await server.start();

  runApp(MyApp(cameraService: cameraService, server: server, cameras: cameras));
}

class MyApp extends StatelessWidget {
  final CameraService cameraService;
  final WebSocketServer server;
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameraService,
    required this.server,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraPage(
        cameraService: cameraService,
        server: server,
        cameras: cameras,
      ),
    );
  }
}
