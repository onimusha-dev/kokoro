import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class SharedImage {
  final String name;
  final String url;
  final DateTime modifiedAt;
  final int sizeBytes;

  const SharedImage({
    required this.name,
    required this.url,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  factory SharedImage.fromJson(Map<String, dynamic> json, String baseUrl) {
    final rawUrl = json['url'] as String? ?? '';
    return SharedImage(
      name: json['name'] as String? ?? 'unknown',
      url: rawUrl.startsWith('http') ? rawUrl : '$baseUrl$rawUrl',
      modifiedAt: DateTime.tryParse(json['modifiedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class GalleryService extends ChangeNotifier {
  HttpClient? _httpClient;
  Timer? _refreshTimer;

  String? _baseUrl;
  bool _isConnected = false;
  String _errorMessage = '';
  List<SharedImage> _images = [];

  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  List<SharedImage> get images => List.unmodifiable(_images);
  String? get baseUrl => _baseUrl;

  Future<void> connect(String ipAddress) async {
    disconnect();
    _baseUrl = 'http://$ipAddress:8000';
    _errorMessage = '';
    notifyListeners();

    _httpClient = HttpClient();

    try {
      await refresh();
      _isConnected = true;
      notifyListeners();

      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        refresh().catchError((_) {});
      });
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_baseUrl == null) {
      return;
    }

    final client = _httpClient ??= HttpClient();
    final uri = Uri.parse('$_baseUrl/api/images');
    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Server returned ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    final list = decoded is List ? decoded : const [];

    _images = list
        .whereType<Map>()
        .map((item) => SharedImage.fromJson(item.cast<String, dynamic>(), _baseUrl!))
        .toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    _isConnected = true;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> openGallery() async {
    await refresh();
  }

  void disconnect() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _baseUrl = null;
    _isConnected = false;
    _images = [];
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
