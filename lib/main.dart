import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kokoro/utils/get_local_ip.dart';

import 'camera_service.dart';
import 'camera_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
  );

  // Create independent services
  final cameraService = CameraService();
  final server = CameraServer(cameraService);

  // Initialize camera
  await cameraService.initialize(frontCamera);

  // Start server
  await server.start();

  runApp(MyApp(cameraService: cameraService, server: server, cameras: cameras));
}

class MyApp extends StatelessWidget {
  final CameraService cameraService;
  final CameraServer server;
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

class CameraPage extends StatefulWidget {
  final CameraService cameraService;
  final CameraServer server;
  final List<CameraDescription> cameras;

  const CameraPage({
    super.key,
    required this.cameraService,
    required this.server,
    required this.cameras,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String _ipAddress = 'Loading...';
  bool _isFrontCamera = true;
  bool _isServerRunning = true;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    _loadIpAddress();
  }

  Future<void> _loadIpAddress() async {
    final ip = await getWifiIp();
    if (mounted) {
      setState(() {
        _ipAddress = ip ?? 'No IP found';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return; // Prevent multiple switches

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      // Get the new camera description
      final newCamera = _isFrontCamera
          ? widget.cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
            )
          : widget.cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
            );

      // Use the server's switchCamera method (doesn't restart server)
      final success = await widget.server.switchCamera(newCamera);

      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
          if (success) {
            _isFrontCamera = !_isFrontCamera;
            _isServerRunning = widget.server.isRunning;
          }
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Switched to ${_isFrontCamera ? "Front" : "Rear"} Camera',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to switch camera'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error switching camera: $e');
      }
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleServer() async {
    try {
      if (_isServerRunning) {
        await widget.server.stop();
        if (mounted) {
          setState(() => _isServerRunning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server stopped'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await widget.server.start();
        if (mounted) {
          setState(() => _isServerRunning = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Camera Server Status:',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _isServerRunning ? '🟢 Running' : '🔴 Stopped',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isServerRunning ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera:',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isFrontCamera ? '📷 Front Camera' : '📷 Rear Camera',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (_isSwitchingCamera) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Server IP Address:',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _ipAddress,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Port: 8000',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text(
              'Open this URL in your browser:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Text(
              _ipAddress != 'Loading...' && _ipAddress != 'No IP found'
                  ? 'http://$_ipAddress:8000'
                  : 'Waiting for IP...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadIpAddress,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh IP'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSwitchingCamera ? null : _switchCamera,
                  icon: Icon(
                    _isSwitchingCamera
                        ? Icons.hourglass_empty
                        : Icons.flip_camera_ios,
                  ),
                  label: Text(
                    _isSwitchingCamera ? 'Switching...' : 'Switch Camera',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _toggleServer,
              icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.server.dispose();
    widget.cameraService.dispose();
    super.dispose();
  }
}
