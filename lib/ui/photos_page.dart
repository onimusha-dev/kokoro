import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/gallery/image_gallery_service.dart';

class PhotosPage extends StatefulWidget {
  final ImageGalleryService galleryService;

  const PhotosPage({super.key, required this.galleryService});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  List<AssetEntity> _images = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  PermissionState? _permissionState;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    setState(() {
      _isLoading = true;
    });
    
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    setState(() {
      _permissionState = ps;
    });

    if (ps.isAuth || ps == PermissionState.limited) {
      _hasPermission = true;
      await _loadImages();
    } else {
      _hasPermission = false;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access photos')),
        );
      }
    }
  }

  Future<void> _loadImages() async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (paths.isEmpty) {
      setState(() {
        _images = [];
        _isLoading = false;
      });
      return;
    }

    final AssetPathEntity recentPath = paths.first;
    final List<AssetEntity> entities = await recentPath.getAssetListPaged(page: 0, size: 100);

    setState(() {
      _images = entities;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _requestPermissionAndLoad();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      return Center(
        child: Text('Permission denied ($_permissionState). Please allow access to photos.'),
      );
    }

    if (_images.isEmpty) {
      return const Center(child: Text('No photos yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GridTile(
            footer: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text(
                image.title ?? 'Image',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            child: FutureBuilder<Uint8List?>(
              future: image.thumbnailData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        );
      },
    );
  }
}
