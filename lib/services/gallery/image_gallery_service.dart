import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'dart:convert';

class GalleryImage {
  final String name;
  final String url;
  final DateTime modifiedAt;
  final int sizeBytes;

  const GalleryImage({
    required this.name,
    required this.url,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'modifiedAt': modifiedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };
}

class ImageGalleryService {
  static const String _galleryDirName = 'kokoro_gallery';

  Directory? _galleryDir;

  Directory? get galleryDirectory => _galleryDir;

  Future<void> initialize() async {
    if (_galleryDir != null) {
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final galleryDir = Directory('${docsDir.path}/$_galleryDirName');
    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }
    _galleryDir = galleryDir;
  }

  Future<File> saveCapturedPhoto(XFile photo) async {
    await initialize();

    final sourceFile = File(photo.path);
    if (!await sourceFile.exists()) {
      throw StateError('Captured photo is missing on disk');
    }

    final extension = _extensionFromPath(photo.path);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$extension';
    final targetFile = File('${_galleryDir!.path}/$fileName');

    await sourceFile.copy(targetFile.path);
    return targetFile;
  }

  Future<List<GalleryImage>> listImages(Uri baseUri) async {
    await initialize();

    final directory = _galleryDir!;
    final entries = <GalleryImage>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final path = entity.path;
      if (!_isImageFile(path)) {
        continue;
      }

      final stat = await entity.stat();
      final name = path.split(Platform.pathSeparator).last;
      entries.add(
        GalleryImage(
          name: name,
          url: '${baseUri.origin}/images/${Uri.encodeComponent(name)}',
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<File?> fileForName(String name) async {
    await initialize();
    final safeName = name.split('/').last.split('\\').last;
    final file = File('${_galleryDir!.path}/$safeName');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<Response> apiImagesResponse(Uri baseUri) async {
    final images = await listImages(baseUri);
    return Response.ok(jsonEncode(images.map((image) => image.toJson()).toList()),
        headers: const {'Content-Type': 'application/json; charset=utf-8'});
  }

  Response htmlLandingPage() {
    return Response.ok(
      _buildLandingPage(),
      headers: const {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  String _buildLandingPage() {
    return r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Kokoro Gallery</title>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; }
    header { padding: 20px 24px; background: linear-gradient(135deg, #111827, #1e293b); position: sticky; top: 0; }
    h1 { margin: 0; font-size: 22px; }
    p { margin: 8px 0 0; color: #94a3b8; }
    main { padding: 20px 24px 40px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 16px; }
    .card { background: #111827; border: 1px solid #1f2937; border-radius: 16px; overflow: hidden; }
    .thumb { width: 100%; aspect-ratio: 1 / 1; object-fit: cover; background: #020617; display: block; }
    .meta { padding: 12px; font-size: 12px; color: #94a3b8; word-break: break-all; }
    .empty { padding: 32px; text-align: center; color: #94a3b8; border: 1px dashed #334155; border-radius: 16px; }
  </style>
</head>
<body>
  <header>
    <h1>Kokoro Gallery</h1>
    <p>Open the desktop app and point it at this phone's IP address.</p>
  </header>
  <main>
    <div id="grid" class="grid"></div>
    <div id="empty" class="empty" hidden>No shared images yet.</div>
  </main>
  <script>
    async function loadImages() {
      const response = await fetch('/api/images');
      const images = await response.json();
      const grid = document.getElementById('grid');
      const empty = document.getElementById('empty');
      grid.innerHTML = '';
      empty.hidden = images.length !== 0;
      for (const image of images) {
        const card = document.createElement('a');
        card.className = 'card';
        card.href = image.url;
        card.target = '_blank';
        card.rel = 'noreferrer';
        card.innerHTML = `
          <img class="thumb" src="${image.url}" alt="${image.name}" loading="lazy" />
          <div class="meta">${image.name}<br>${new Date(image.modifiedAt).toLocaleString()}</div>
        `;
        grid.appendChild(card);
      }
    }
    loadImages();
    setInterval(loadImages, 3000);
  </script>
</body>
</html>
''';
  }

  String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dot).toLowerCase();
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }
}
