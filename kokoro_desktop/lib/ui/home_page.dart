import 'package:flutter/material.dart';
import '../services/stream_service.dart';

class HomePage extends StatefulWidget {
  final StreamService streamService;

  const HomePage({Key? key, required this.streamService}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController(text: '10.23.152.19');
  
  @override
  void initState() {
    super.initState();
    widget.streamService.addListener(_onStreamStateChanged);
  }

  @override
  void dispose() {
    widget.streamService.removeListener(_onStreamStateChanged);
    _ipController.dispose();
    super.dispose();
  }

  void _onStreamStateChanged() {
    setState(() {}); // Rebuild UI on connection or frame update
  }

  void _toggleConnection() {
    if (widget.streamService.isConnected) {
      widget.streamService.disconnect();
    } else {
      final ip = _ipController.text.trim();
      if (ip.isNotEmpty) {
        widget.streamService.connect(ip);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark aesthetic
      appBar: AppBar(
        title: const Text('Kokoro Desktop'),
        backgroundColor: Colors.black54,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Left Sidebar for controls
          Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF252526),
              border: Border(right: BorderSide(color: Colors.black26, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Connect to Camera',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Server IP Address',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.wifi, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _toggleConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.streamService.isConnected 
                        ? Colors.redAccent 
                        : Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.streamService.isConnected ? 'Disconnect' : 'Connect',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.streamService.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Text(
                      widget.streamService.errorMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.streamService.isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.streamService.isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Right Main Area for Video Feed
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              color: const Color(0xFF1E1E1E),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildVideoFeed(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed() {
    if (!widget.streamService.isConnected) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No Video Feed',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (widget.streamService.currentFrame == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return Image.memory(
      widget.streamService.currentFrame!,
      key: const ValueKey('video_feed'),
      fit: BoxFit.contain,
      gaplessPlayback: true, // Prevents flickering when the image bytes update
    );
  }
}
