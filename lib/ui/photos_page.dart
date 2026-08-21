import 'package:flutter/material.dart';

import '../services/gallery/image_gallery_service.dart';

class PhotosPage extends StatefulWidget {
  final ImageGalleryService galleryService;

  const PhotosPage({super.key, required this.galleryService});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  late Future<List<GalleryImage>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _imagesFuture = widget.galleryService.listImages(Uri.parse('http://127.0.0.1:8000'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: FutureBuilder<List<GalleryImage>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          final images = snapshot.data ?? const <GalleryImage>[];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (images.isEmpty) {
            return const Center(child: Text('No photos yet'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GridTile(
                  footer: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      image.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  child: Image.network(image.url, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _reload();
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
