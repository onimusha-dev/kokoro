import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'camera_service.dart';

class CameraServer {
  final CameraService cameraService;
  HttpServer? _server;
  bool _isRunning = false;

  final List<StreamController<List<int>>> _clients = [];
  bool _processing = false;
  bool _isStreaming = false;

  CameraServer(this.cameraService);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) {
      if (kDebugMode) {
        print('Server is already running');
      }
      return;
    }

    try {
      // Ensure camera is streaming
      if (!cameraService.isInitialized) {
        throw Exception('Camera not initialized');
      }

      // Start image stream if not already streaming
      if (!_isStreaming) {
        await cameraService.startImageStream();
        cameraService.addFrameListener(_processFrame);
        _isStreaming = true;
      }

      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_handleRequest);

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8000);

      _isRunning = true;

      if (kDebugMode) {
        print('Camera server running on port ${_server!.port}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start server: $e');
      }
      rethrow;
    }
  }

  // New method to switch camera without restarting server
  Future<bool> switchCamera(CameraDescription newCamera) async {
    try {
      if (!_isRunning) {
        throw Exception('Server is not running');
      }

      // Remove old frame listener
      cameraService.removeFrameListener(_processFrame);

      // Stop current stream
      if (_isStreaming) {
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      // Switch camera
      final success = await cameraService.switchCamera(newCamera);

      if (!success) {
        throw Exception('Failed to switch camera');
      }

      // Restart image stream with new camera
      await cameraService.startImageStream();
      cameraService.addFrameListener(_processFrame);
      _isStreaming = true;

      if (kDebugMode) {
        print('Camera switched successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error switching camera: $e');
      }

      // Try to recover
      await _recoverStream();
      return false;
    }
  }

  // Recovery method if camera switch fails
  Future<void> _recoverStream() async {
    try {
      if (_isStreaming) {
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      cameraService.removeFrameListener(_processFrame);

      // Restart with current camera
      if (cameraService.isInitialized) {
        await cameraService.startImageStream();
        cameraService.addFrameListener(_processFrame);
        _isStreaming = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to recover stream: $e');
      }
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<Response> _handleRequest(Request request) async {
    if (request.url.path == '') {
      return Response.ok(
        '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width">
  <title>Camera</title>
  <style>
    body {
      margin: 0;
      background: black;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
    }

    img {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
  </style>
</head>

<body>
  <img src="/stream">
</body>
</html>
''',
        headers: {'Content-Type': 'text/html'},
      );
    }

    if (request.url.path == 'stream') {
      final controller = StreamController<List<int>>();

      _clients.add(controller);

      controller.onCancel = () {
        _clients.remove(controller);
      };

      return Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'multipart/x-mixed-replace; boundary=frame',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      );
    }

    return Response.notFound('Not found');
  }

  void _processFrame(CameraImage frame) async {
    if (_processing || _clients.isEmpty) {
      return;
    }

    _processing = true;

    try {
      final image = _convertYUV420(frame);

      final jpeg = img.encodeJpg(image, quality: 60);

      final bytes = Uint8List.fromList([
        ...'--frame\r\n'.codeUnits,
        ...'Content-Type: image/jpeg\r\n'.codeUnits,
        ...'Content-Length: ${jpeg.length}\r\n\r\n'.codeUnits,
        ...jpeg,
        ...'\r\n'.codeUnits,
      ]);

      for (final client in List.of(_clients)) {
        if (!client.isClosed) {
          client.add(bytes);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Frame error: $e');
      }
    } finally {
      _processing = false;
    }
  }

  img.Image _convertYUV420(CameraImage frame) {
    final width = frame.width;
    final height = frame.height;

    final image = img.Image(width: width, height: height);

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];

    final y = yPlane.bytes;
    final u = uPlane.bytes;
    final v = vPlane.bytes;

    final yStride = yPlane.bytesPerRow;
    final uStride = uPlane.bytesPerRow;
    final vStride = vPlane.bytesPerRow;

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        final yIndex = py * yStride + px;
        final uvX = px ~/ 2;
        final uvY = py ~/ 2;
        final uIndex = uvY * uStride + uvX * uPixelStride;
        final vIndex = uvY * vStride + uvX * vPixelStride;

        final yValue = y[yIndex];
        final uValue = u[uIndex];
        final vValue = v[vIndex];

        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round();
        int b = (yValue + 1.772 * (uValue - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(px, py, r, g, b);
      }
    }

    return image;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    try {
      // Stop streaming
      if (_isStreaming) {
        cameraService.removeFrameListener(_processFrame);
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      // Close all clients
      for (final client in _clients) {
        await client.close();
      }
      _clients.clear();

      // Close server
      await _server?.close();
      _server = null;
      _isRunning = false;

      if (kDebugMode) {
        print('Camera server stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping server: $e');
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    cameraService.removeFrameListener(_processFrame);
  }
}
