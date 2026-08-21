import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera/camera_service.dart';
import '../services/gallery/image_gallery_service.dart';
import '../services/websocket/websocket_server.dart';
import '../utils/get_local_ip.dart';
import 'camera_page.dart';
import 'notifications_page.dart';
import 'photos_page.dart';

class HomePage extends StatefulWidget {
  final CameraService cameraService;
  final WebSocketServer server;
  final ImageGalleryService galleryService;
  final List<CameraDescription> cameras;

  const HomePage({
    super.key,
    required this.cameraService,
    required this.server,
    required this.galleryService,
    required this.cameras,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _ip = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await getWifiIp();
    if (mounted) {
      setState(() => _ip = ip ?? 'No IP found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Kokoro',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Phone IP: $_ip'),
              const SizedBox(height: 20),
              _MenuTile(
                title: 'Photos',
                subtitle: 'Open the shared image list',
                icon: Icons.photo_library_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotosPage(galleryService: widget.galleryService),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MenuTile(
                title: 'Webcam',
                subtitle: 'Turn on the live camera only when you approve it',
                icon: Icons.videocam_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraPage(
                      cameraService: widget.cameraService,
                      server: widget.server,
                      galleryService: widget.galleryService,
                      cameras: widget.cameras,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MenuTile(
                title: 'Notifications',
                subtitle: 'Placeholder for alerts and device notices',
                icon: Icons.notifications_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
