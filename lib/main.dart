import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'services/camera/camera_service.dart';
import 'services/gallery/image_gallery_service.dart';
import 'services/websocket/websocket_server.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

  // Create independent services
  final cameraService = CameraService();
  final galleryService = ImageGalleryService();
  await galleryService.initialize();
  final server = WebSocketServer(cameraService, galleryService);

  // Initialize camera
  await cameraService.initialize(frontCamera);

  // Start server
  await server.start();

  runApp(
    MyApp(
      cameraService: cameraService,
      server: server,
      galleryService: galleryService,
      cameras: cameras,
    ),
  );
}

class MyApp extends StatelessWidget {
  final CameraService cameraService;
  final WebSocketServer server;
  final ImageGalleryService galleryService;
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameraService,
    required this.server,
    required this.galleryService,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(
        cameraService: cameraService,
        server: server,
        galleryService: galleryService,
        cameras: cameras,
      ),
    );
  }
}
