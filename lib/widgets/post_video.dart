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
  String? _posterUrl;
  bool _showControls = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _posterUrl = _cloudinaryPoster(widget.url);
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(false)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setVolume(1.0);
        _muted = false;
        // Nudge some platforms to render first frame
        _controller.play();
        _controller.pause();
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
    if (_error) return _errorBox();

    if (!_initialized) {
      final placeholder = _posterUrl != null
          ? Image.network(
              _posterUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stack) => const Center(child: CircularProgressIndicator()),
            )
          : const Center(child: CircularProgressIndicator());
      return AspectRatio(aspectRatio: 16 / 9, child: placeholder);
    }

    final aspect = _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio;
    final showPoster = (_posterUrl != null) && (!_initialized || !_controller.value.isPlaying);

    Widget player = Stack(
      alignment: Alignment.center,
      children: [
        if (showPoster)
          Positioned.fill(
            child: Image.network(
              _posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: VideoPlayer(_controller),
        ),
        if (!_controller.value.isPlaying)
          _PlayOverlay(isPlaying: _controller.value.isPlaying, onPressed: _toggle),
        if (_showControls)
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: VideoProgressColors(
                    playedColor: Colors.blue.shade400,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ControlIcon(icon: Icons.replay_10, onTap: () => _skip(const Duration(seconds: -10))),
                    _ControlIcon(
                      icon: _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      onTap: _toggle,
                      size: 36,
                    ),
                    _ControlIcon(icon: Icons.forward_10, onTap: () => _skip(const Duration(seconds: 10))),
                    _ControlIcon(icon: Icons.refresh, onTap: _refresh),
                    _ControlIcon(icon: _muted ? Icons.volume_off : Icons.volume_up, onTap: _toggleMute),
                    _ControlIcon(icon: Icons.fullscreen, onTap: _openFullscreen),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    player = AspectRatio(aspectRatio: aspect, child: player);
    if (widget.maxHeight != null) {
      player = ConstrainedBox(constraints: BoxConstraints(maxHeight: widget.maxHeight!), child: player);
    }

    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(color: const Color(0xFF111111), child: player));
  }

  Future<void> _openFullscreen() async {
    final current = _controller.value.position;
    final newPos = await Navigator.of(context).push<Duration?>(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(url: widget.url, startAt: current, muted: _muted),
      ),
    );
    if (!mounted) return;
    if (newPos != null) await _controller.seekTo(newPos);
  }

  Future<void> _skip(Duration delta) async {
    final pos = _controller.value.position + delta;
    final clamped = pos < Duration.zero ? Duration.zero : (pos > _controller.value.duration ? _controller.value.duration : pos);
    await _controller.seekTo(clamped);
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

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  void _refresh() async {
    try {
      await _controller.pause();
      await _controller.seekTo(Duration.zero);
      setState(() {});
    } catch (_) {}
  }

  String? _cloudinaryPoster(String url) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) return null;
    final u = Uri.parse(url);
    final segs = List<String>.from(u.pathSegments);
    final uploadIdx = segs.indexOf('upload');
    if (uploadIdx == -1) return null;
    final trans = 'so_0,f_jpg';
    final hasTrans = uploadIdx + 1 < segs.length && !segs[uploadIdx + 1].startsWith('v');
    if (hasTrans) {
      if (!segs[uploadIdx + 1].contains('so_0')) segs[uploadIdx + 1] = '${segs[uploadIdx + 1]},$trans';
    } else {
      segs.insert(uploadIdx + 1, trans);
    }
    final last = segs.last;
    final m = RegExp(r'^(.*)\.(mp4|mov|webm|mkv)$', caseSensitive: false).firstMatch(last);
    if (m != null) segs[segs.length - 1] = '${m.group(1)}.jpg';
    return Uri(scheme: u.scheme, host: u.host, path: '/' + segs.join('/')).toString();
  }

  Widget _errorBox() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
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
          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
          child: IconButton(iconSize: 48, color: Colors.white, onPressed: onPressed, icon: const Icon(Icons.play_arrow)),
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _ControlIcon({required this.icon, required this.onTap, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return InkResponse(onTap: onTap, radius: size + 6, child: Icon(icon, color: Colors.white, size: size));
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  final Duration startAt;
  final bool muted;
  const _FullscreenVideoPage({required this.url, required this.startAt, required this.muted});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  late bool _muted;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(false)
      ..initialize().then((_) async {
        await _controller.seekTo(widget.startAt);
        await _controller.play();
        _controller.setVolume(_muted ? 0.0 : 1.0);
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    final pos = _controller.value.position;
    _controller.dispose();
    Navigator.of(context).pop(pos);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: _ready
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(_controller, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8)),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _ControlIcon(icon: Icons.replay_10, onTap: () => _skip(const Duration(seconds: -10))),
                                _ControlIcon(
                                  icon: _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  onTap: () => setState(() {
                                    if (_controller.value.isPlaying) {
                                      _controller.pause();
                                    } else {
                                      _controller.play();
                                    }
                                  }),
                                  size: 44,
                                ),
                                _ControlIcon(icon: Icons.forward_10, onTap: () => _skip(const Duration(seconds: 10))),
                                _ControlIcon(
                                  icon: Icons.refresh,
                                  onTap: () async {
                                    await _controller.pause();
                                    await _controller.seekTo(Duration.zero);
                                    setState(() {});
                                  },
                                ),
                                _ControlIcon(
                                  icon: _muted ? Icons.volume_off : Icons.volume_up,
                                  onTap: () => setState(() {
                                    _muted = !_muted;
                                    _controller.setVolume(_muted ? 0.0 : 1.0);
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(_controller.value.position),
                        ),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _skip(Duration delta) async {
    final pos = _controller.value.position + delta;
    final d = _controller.value.duration;
    final clamped = pos < Duration.zero ? Duration.zero : (pos > d ? d : pos);
    await _controller.seekTo(clamped);
  }
}
