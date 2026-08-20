import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/camera/camera_service.dart';
import '../services/websocket/websocket_server.dart';
import '../utils/get_local_ip.dart';

class CameraPage extends StatefulWidget {
  final CameraService cameraService;
  final WebSocketServer server;
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
      backgroundColor: const Color(0xFFF8F9FA), // Clean off-white background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top: Camera Preview (Modern Card Style)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.cameraService.isInitialized && widget.cameraService.controller != null
                          ? CameraPreview(widget.cameraService.controller!)
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                      // Add a subtle gradient overlay to make it pop
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Middle: Connection Info
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_tethering, size: 28, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _ipAddress != 'Loading...' && _ipAddress != 'No IP found'
                          ? 'http://$_ipAddress:8000'
                          : 'Listen on this port',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B), // Slate 800
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isServerRunning ? '🟢 Server is broadcasting live' : '🔴 Server is currently offline',
                      style: TextStyle(
                        fontSize: 15,
                        color: _isServerRunning ? Colors.green.shade600 : Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Bottom: Buttons
              Row(
                children: [
                  // Server Toggle Button
                  Expanded(
                    child: SizedBox(
                      height: 120, // Make buttons large and squarish
                      child: ElevatedButton(
                        onPressed: _toggleServer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isServerRunning ? Colors.redAccent : Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: (_isServerRunning ? Colors.redAccent : Colors.green).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isServerRunning ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isServerRunning ? 'Server Off' : 'Server On',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Camera Switch Button
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: ElevatedButton(
                        onPressed: _isSwitchingCamera ? null : _switchCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155), // Slate 700
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSwitchingCamera)
                              const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            else
                              const Icon(
                                Icons.cameraswitch_rounded,
                                size: 40,
                                color: Colors.blueAccent,
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera Change',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
