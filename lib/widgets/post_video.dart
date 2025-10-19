import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PostVideo extends StatefulWidget {
  final String url;
  final double? maxHeight;
  const PostVideo({super.key, required this.url, this.maxHeight});

  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _errorBox();
    }
    if (!_initialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final aspect = _controller.value.aspectRatio == 0
        ? 16 / 9
        : _controller.value.aspectRatio;

    Widget player = Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: VideoPlayer(_controller),
        ),
        _PlayOverlay(isPlaying: _controller.value.isPlaying, onPressed: _toggle),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: Column(
            children: [
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.blue.shade400,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    player = AspectRatio(aspectRatio: aspect, child: player);

    if (widget.maxHeight != null) {
      player = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: player,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(color: const Color(0xFF111111), child: player),
    );
  }

  void _toggle() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  Widget _errorBox() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
        ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  const _PlayOverlay({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isPlaying,
      child: AnimatedOpacity(
        opacity: isPlaying ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 48,
            color: Colors.white,
            onPressed: onPressed,
            icon: const Icon(Icons.play_arrow),
          ),
        ),
      ),
    );
  }
}

