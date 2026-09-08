import 'dart:async';
import 'package:flutter/material.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void initState() {
    super.initState();

    Timer(
      const Duration(seconds: 2),
      widget.onFinished,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches the new logo artwork's own background exactly (see
      // assets/images/logo_splash.png) instead of the old brand navy.
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset(
            'assets/images/logo_splash.png',
            width: 160,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}
