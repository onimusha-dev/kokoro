import 'package:flutter/material.dart';

import '../services/gallery_service.dart';
import '../services/stream_service.dart';

class HomePage extends StatefulWidget {
  final GalleryService galleryService;
  final StreamService streamService;

  const HomePage({
    super.key,
    required this.galleryService,
    required this.streamService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController();
  SharedImage? _selectedImage;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.galleryService.addListener(_onChanged);
    widget.streamService.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.galleryService.removeListener(_onChanged);
    widget.streamService.removeListener(_onChanged);
    _ipController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_selectedImage != null &&
        !widget.galleryService.images.any((image) => image.url == _selectedImage!.url)) {
      _selectedImage = null;
    }
    setState(() {});
  }

  Future<void> _connectImages() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    await widget.galleryService.connect(ip);
    if (mounted && widget.galleryService.images.isNotEmpty) {
      setState(() => _selectedImage = widget.galleryService.images.first);
    }
  }

  Future<void> _connectWebcam() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    widget.streamService.connect(ip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Images',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'Webcam',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? _galleryView() : _webcamView()),
          ],
        ),
      ),
    );
  }

  Widget _galleryView() {
    final service = widget.galleryService;
    return Row(
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111827), Color(0xFF0F172A)],
            ),
            border: Border(right: BorderSide(color: Color(0xFF1F2937))),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Kokoro Gallery', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('Browse shared images from the phone.', style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 20),
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Phone IP'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: service.isConnected ? service.disconnect : _connectImages,
                  child: Text(service.isConnected ? 'Disconnect' : 'Connect'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: service.isConnected ? () => service.refresh() : null,
                  child: const Text('Refresh'),
                ),
                const SizedBox(height: 16),
                _StatusCard(
                  title: service.isConnected ? 'Connected' : 'Offline',
                  subtitle: '${service.images.length} images',
                  detail: service.errorMessage.isEmpty ? (service.baseUrl ?? '') : service.errorMessage,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewCard(image: _selectedImage),
                const SizedBox(height: 16),
                Expanded(
                  child: service.isConnected
                      ? service.images.isEmpty
                          ? const Center(
                              child: Text('No shared images yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: service.images.length,
                              itemBuilder: (_, index) {
                                final image = service.images[index];
                                final selected = _selectedImage?.url == image.url;
                                return _GalleryTile(
                                  image: image,
                                  selected: selected,
                                  onTap: () => setState(() => _selectedImage = image),
                                );
                              },
                            )
                      : const Center(
                          child: Text('Connect to a phone IP address.', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _webcamView() {
    final service = widget.streamService;
    return Row(
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111827), Color(0xFF0F172A)],
            ),
            border: Border(right: BorderSide(color: Color(0xFF1F2937))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Kokoro Webcam', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Connect to the live camera stream on the phone.', style: TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Phone IP'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: service.isConnected ? service.disconnect : _connectWebcam,
                child: Text(service.isConnected ? 'Disconnect' : 'Connect'),
              ),
              const SizedBox(height: 16),
              _StatusCard(
                title: service.isConnected ? 'Streaming' : 'Offline',
                subtitle: service.currentFrame == null ? 'No frame yet' : 'Live frame received',
                detail: service.errorMessage,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              clipBehavior: Clip.antiAlias,
              child: service.currentFrame == null
                  ? const Center(
                      child: Text('Connect to see the webcam feed.', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : Image.memory(service.currentFrame!, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFF111827),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF334155))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF334155))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5)),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFF2563EB) : const Color(0xFF111827),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8))),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final SharedImage? image;
  const _PreviewCard({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Center(child: Text('Select an image to preview.', style: TextStyle(color: Color(0xFF94A3B8))))
          : Image.network(image!.url, fit: BoxFit.contain),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final SharedImage image;
  final bool selected;
  final VoidCallback onTap;

  const _GalleryTile({required this.image, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF60A5FA) : const Color(0xFF1F2937), width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Image.network(image.url, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
