import 'package:flutter/material.dart';
import 'services/gallery_service.dart';
import 'services/stream_service.dart';
import 'ui/home_page.dart';

void main() {
  runApp(const KokoroDesktopApp());
}

class KokoroDesktopApp extends StatelessWidget {
  const KokoroDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kokoro Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: HomePage(
        galleryService: GalleryService(),
        streamService: StreamService(),
      ),
    );
  }
}
