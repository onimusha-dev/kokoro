import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../camera/camera_service.dart';
import '../gallery/image_gallery_service.dart';

class WebSocketServer {
  final CameraService cameraService;
  final ImageGalleryService imageGalleryService;

  HttpServer? _server;
  bool _isRunning = false;

  final List<WebSocketChannel> _clients = [];
  bool _processing = false;
  bool _isStreaming = false;

  WebSocketServer(this.cameraService, this.imageGalleryService);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) {
      if (kDebugMode) {
        print('WebSocket server is already running');
      }
      return;
    }

    try {
      if (!cameraService.isInitialized) {
        throw Exception('Camera not initialized');
      }

      await imageGalleryService.initialize();

      final wsHandler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
        _clients.add(webSocket);
        if (kDebugMode) {
          print('Client connected. Total clients: ${_clients.length}');
        }

        webSocket.stream.listen((message) {}, onDone: () {
          _clients.remove(webSocket);
          if (kDebugMode) {
            print('Client disconnected. Total clients: ${_clients.length}');
          }
        });
      });

      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler((Request request) async {
        final path = request.url.path;

        if (path.isEmpty || path == 'gallery' || path == 'index.html') {
          return imageGalleryService.htmlLandingPage();
        }

        if (path == 'api/images') {
          return imageGalleryService.apiImagesResponse(request.requestedUri);
        }

        if (path.startsWith('images/')) {
          final name = request.url.pathSegments.length > 1 ? request.url.pathSegments[1] : '';
          return _serveGalleryImage(name);
        }

        if (path == 'ws') {
          return wsHandler(request);
        }

        return Response.notFound('Not found');
      });

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8000);
      _isRunning = true;

      if (kDebugMode) {
        print('Server running on port ${_server!.port}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start server: $e');
      }
      rethrow;
    }
  }

  Future<void> enableWebcam() async {
    if (!_isRunning) {
      throw Exception('Server is not running');
    }
    if (_isStreaming) {
      return;
    }
    await cameraService.startImageStream();
    cameraService.addFrameListener(_processFrame);
    _isStreaming = true;
  }

  Future<void> disableWebcam() async {
    if (!_isStreaming) {
      return;
    }
    cameraService.removeFrameListener(_processFrame);
    await cameraService.stopImageStream();
    _isStreaming = false;
  }

  Future<Response> _serveGalleryImage(String name) async {
    if (name.isEmpty) {
      return Response.notFound('Image not found');
    }

    final file = await imageGalleryService.fileForName(Uri.decodeComponent(name));
    if (file == null) {
      return Response.notFound('Image not found');
    }

    final bytes = await file.readAsBytes();
    return Response.ok(
      bytes,
      headers: {
        'Content-Type': _contentTypeForPath(file.path),
        'Cache-Control': 'no-store',
      },
    );
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Future<bool> switchCamera(CameraDescription newCamera) async {
    try {
      if (!_isRunning) {
        throw Exception('Server is not running');
      }

      cameraService.removeFrameListener(_processFrame);

      if (_isStreaming) {
        await disableWebcam();
      }

      final success = await cameraService.switchCamera(newCamera);

      if (!success) {
        throw Exception('Failed to switch camera');
      }

      await enableWebcam();

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

  Future<File?> captureAndSavePhoto() async {
    if (!_isRunning) {
      throw Exception('Server is not running');
    }

    final wasStreaming = _isStreaming;
    try {
      if (_isStreaming) {
        cameraService.removeFrameListener(_processFrame);
        await cameraService.stopImageStream();
        _isStreaming = false;
      }

      final photo = await cameraService.takePhoto();
      if (photo == null) {
        return null;
      }

      return await imageGalleryService.saveCapturedPhoto(photo);
    } finally {
      if (wasStreaming && cameraService.isInitialized) {
        await enableWebcam();
      }
    }
  }

  Future<void> _recoverStream() async {
    try {
      if (_isStreaming) {
        await disableWebcam();
      }

      cameraService.removeFrameListener(_processFrame);

      if (cameraService.isInitialized) {
        await enableWebcam();
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
    const step = 2;
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

        if (uIndex >= u.length) uIndex = u.length - 1;
        if (vIndex >= v.length) vIndex = v.length - 1;

        final yValue = y[yIndex];
        final uValue = u[uIndex];
        final vValue = v[vIndex];

        final r = (yValue + 1.402 * (vValue - 128)).round();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
        final b = (yValue + 1.772 * (uValue - 128)).round();

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
        print('Server stopped');
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
