import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../camera/camera_service.dart';

class WebSocketServer {
  final CameraService cameraService;
  HttpServer? _server;
  bool _isRunning = false;

  final List<WebSocketChannel> _clients = [];
  bool _processing = false;
  bool _isStreaming = false;

  WebSocketServer(this.cameraService);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) {
      if (kDebugMode) {
        print('WebSocket Server is already running');
      }
      return;
    }

    try {
      if (!cameraService.isInitialized) {
        throw Exception('Camera not initialized');
      }

      if (!_isStreaming) {
        await cameraService.startImageStream();
        cameraService.addFrameListener(_processFrame);
        _isStreaming = true;
      }

      final wsHandler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
        _clients.add(webSocket);
        if (kDebugMode) {
          print('Client connected. Total clients: ${_clients.length}');
        }

        webSocket.stream.listen((message) {
          // Handle incoming messages if needed
        }, onDone: () {
          _clients.remove(webSocket);
          if (kDebugMode) {
            print('Client disconnected. Total clients: ${_clients.length}');
          }
        });
      });

      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler((Request request) {
        if (request.url.path == '') {
          return Response.ok(
            _getHtmlClient(),
            headers: {'Content-Type': 'text/html'},
          );
        } else if (request.url.path == 'ws') {
          return wsHandler(request);
        }
        return Response.notFound('Not found');
      });

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8000);
      _isRunning = true;

      if (kDebugMode) {
        print('WebSocket server running on port ${_server!.port}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start WebSocket server: $e');
      }
      rethrow;
    }
  }

  String _getHtmlClient() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WebSocket Camera Feed</title>
  <style>
    body {
      margin: 0;
      background: #121212;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100vh;
      color: white;
      font-family: sans-serif;
    }
    #feed {
      max-width: 100%;
      max-height: 90vh;
      object-fit: contain;
      background: #000;
    }
    #status {
      margin-top: 10px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <img id="feed" alt="Waiting for feed..." />
  <div id="status">Connecting...</div>

  <script>
    const img = document.getElementById('feed');
    const status = document.getElementById('status');
    const wsUrl = `ws://\${window.location.host}/ws`;
    
    function connect() {
      const ws = new WebSocket(wsUrl);
      ws.binaryType = 'blob';

      ws.onopen = () => {
        status.textContent = 'Connected';
        status.style.color = '#4CAF50';
      };

      ws.onmessage = (event) => {
        const data = event.data;
        const size = data.size || data.length || 0;
        status.textContent = 'Received frame: ' + size + ' bytes';
        status.style.color = '#4CAF50';

        const blob = new Blob([data], { type: 'image/jpeg' });
        const url = URL.createObjectURL(blob);
        const oldUrl = img.src;
        img.src = url;
        
        img.onload = () => {
          if (oldUrl && oldUrl.startsWith('blob:')) {
            URL.revokeObjectURL(oldUrl);
          }
        };
        img.onerror = () => {
          status.textContent = 'Error loading image! Size: ' + size;
          status.style.color = '#F44336';
        };
      };

      ws.onclose = () => {
        status.textContent = 'Disconnected, retrying...';
        status.style.color = '#F44336';
        setTimeout(connect, 2000);
      };

      ws.onerror = (error) => {
        console.error('WebSocket Error:', error);
      };
    }

    connect();
  </script>
</body>
</html>
''';
  }

  Future<bool> switchCamera(CameraDescription newCamera) async {
    try {
      if (!_isRunning) {
        throw Exception('Server is not running');
      }

      cameraService.removeFrameListener(_processFrame);

      if (_isStreaming) {
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      final success = await cameraService.switchCamera(newCamera);

      if (!success) {
        throw Exception('Failed to switch camera');
      }

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
      await _recoverStream();
      return false;
    }
  }

  Future<void> _recoverStream() async {
    try {
      if (_isStreaming) {
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      cameraService.removeFrameListener(_processFrame);

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

  void _processFrame(CameraImage frame) async {
    if (_processing || _clients.isEmpty) {
      return;
    }
    _processing = true;

    try {
      final image = _convertYUV420(frame);
      final jpeg = img.encodeJpg(image, quality: 60);
      
      final bytes = Uint8List.fromList(jpeg);

      for (final client in List.of(_clients)) {
        if (client.closeCode == null) {
          client.sink.add(bytes);
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
    const step = 2; // Downsample for performance (process 1 out of every 4 pixels)
    final width = frame.width ~/ step;
    final height = frame.height ~/ step;
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
      final actualY = py * step;
      for (int px = 0; px < width; px++) {
        final actualX = px * step;
        final yIndex = actualY * yStride + actualX;
        
        final uvX = actualX ~/ 2;
        final uvY = actualY ~/ 2;
        int uIndex = uvY * uStride + uvX * uPixelStride;
        int vIndex = uvY * vStride + uvX * vPixelStride;

        // CRITICAL: Prevent RangeError on some Android devices with padded U/V planes
        if (uIndex >= u.length) uIndex = u.length - 1;
        if (vIndex >= v.length) vIndex = v.length - 1;

        final yValue = y[yIndex];
        final uValue = u[uIndex];
        final vValue = v[vIndex];

        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
        int b = (yValue + 1.772 * (uValue - 128)).round();

        image.setPixelRgb(px, py, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return image;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    try {
      if (_isStreaming) {
        cameraService.removeFrameListener(_processFrame);
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      for (final client in _clients) {
        client.sink.close();
      }
      _clients.clear();

      await _server?.close();
      _server = null;
      _isRunning = false;

      if (kDebugMode) {
        print('WebSocket server stopped');
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
