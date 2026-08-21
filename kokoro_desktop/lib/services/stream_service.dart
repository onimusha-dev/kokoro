import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class StreamService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Uint8List? _currentFrame;
  Uint8List? get currentFrame => _currentFrame;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void connect(String ipAddress) {
    disconnect();

    _errorMessage = '';
    notifyListeners();

    try {
      final wsUrl = Uri.parse('ws://$ipAddress:8000/ws');
      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            notifyListeners();
          }
          if (message is Uint8List) {
            _currentFrame = message;
            notifyListeners();
          }
        },
        onError: (error) {
          _isConnected = false;
          _errorMessage = 'Connection error: $error';
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          _errorMessage = 'Disconnected from server';
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _currentFrame = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
