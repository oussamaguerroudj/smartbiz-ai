import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  VideoPlayerController? _controller;
  bool _isFinished = false;
  bool _initialized = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    // Safety fallback: if video doesn't finish within 3.5s, continue
    _fallbackTimer = Timer(const Duration(milliseconds: 3500), _finish);

    try {
      final controller = VideoPlayerController.asset('assets/video/splash.mp4');
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      controller.addListener(_videoListener);
      await controller.play();
    } catch (e) {
      debugPrint('Failed to play splash video: $e');
      _finish();
    }
  }

  void _videoListener() {
    if (!mounted || _isFinished) return;
    final controller = _controller;
    if (controller == null) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    if (controller.value.isInitialized &&
        duration > Duration.zero &&
        position >= duration) {
      _finish();
    }
  }

  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    _fallbackTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_videoListener);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: SizedBox.expand(
          child: _initialized && controller != null && controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
