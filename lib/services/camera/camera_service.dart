import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  final List<Function(CameraImage)> _frameListeners = [];
  bool _isInitialized = false;

  CameraDescription? _description;

  // Getters
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  // Initialize camera
  Future<bool> initialize(CameraDescription description) async {
    try {
      _description = description;
      _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      _isInitialized = true;

      if (kDebugMode) {
        print('Camera initialized: ${description.name}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
      _isInitialized = false;
      return false;
    }
  }

  // Start image stream
  Future<void> startImageStream() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }

    // Stop any existing stream
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    await _controller!.startImageStream((CameraImage frame) {
      for (var listener in _frameListeners) {
        listener(frame);
      }
    });

    if (kDebugMode) {
      print('Image stream started');
    }
  }

  // Stop image stream
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
      if (kDebugMode) {
        print('Image stream stopped');
      }
    }
  }

  // Add frame listener
  void addFrameListener(Function(CameraImage) listener) {
    _frameListeners.add(listener);
    if (kDebugMode) {
      print('Frame listener added. Total: ${_frameListeners.length}');
    }
  }

  // Remove frame listener
  void removeFrameListener(Function(CameraImage) listener) {
    _frameListeners.remove(listener);
    if (kDebugMode) {
      print('Frame listener removed. Total: ${_frameListeners.length}');
    }
  }

  // Clear all listeners
  void clearListeners() {
    _frameListeners.clear();
    if (kDebugMode) {
      print('All frame listeners cleared');
    }
  }

  // Switch camera
  Future<bool> switchCamera(CameraDescription newDescription) async {
    try {
      if (kDebugMode) {
        print('Switching camera to: ${newDescription.name}');
      }

      // Stop current stream
      await stopImageStream();

      // Dispose current controller
      await dispose();

      // Initialize with new camera
      final success = await initialize(newDescription);

      if (success && kDebugMode) {
        print('Camera switched successfully');
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error switching camera: $e');
      }
      return false;
    }
  }

  // Take photo
  Future<XFile?> takePhoto() async {
    if (_controller == null || !_isInitialized) {
      return null;
    }
    try {
      final photo = await _controller!.takePicture();
      if (kDebugMode) {
        print('Photo taken: ${photo.path}');
      }
      return photo;
    } catch (e) {
      if (kDebugMode) {
        print('Error taking photo: $e');
      }
      return null;
    }
  }

  // Get current camera description
  CameraDescription? get currentCamera => _description;

  // Check if camera is streaming
  bool get isStreaming => _controller?.value.isStreamingImages ?? false;

  // Get camera resolution
  Size get resolution {
    if (_controller != null && _isInitialized) {
      return _controller!.value.previewSize ?? const Size(0, 0);
    }
    return const Size(0, 0);
  }

  // Dispose
  Future<void> dispose() async {
    try {
      await stopImageStream();
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
      _isInitialized = false;
      clearListeners();

      if (kDebugMode) {
        print('Camera service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing camera: $e');
      }
    }
  }
}
