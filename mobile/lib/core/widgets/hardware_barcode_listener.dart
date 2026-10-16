import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/barcode_validator.dart';

/// Wraps a subtree with hardware keyboard listener that detects external
/// USB and Bluetooth HID barcode scanners.
///
/// Barcode scanners act as high-speed keyboards that emit characters in rapid
/// succession (<60ms per character) followed by an Enter or NumpadEnter key.
class HardwareBarcodeListener extends StatefulWidget {
  const HardwareBarcodeListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final bool enabled;

  @override
  State<HardwareBarcodeListener> createState() => _HardwareBarcodeListenerState();
}

class _HardwareBarcodeListenerState extends State<HardwareBarcodeListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeystrokeTime;
  Timer? _resetTimer;

  static const int _maxInterKeyDelayMs = 90;

  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _resetTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) return false;

    final now = DateTime.now();

    // Check if Enter / NumpadEnter / Tab is pressed to complete scanner buffer
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_buffer.isNotEmpty) {
        final code = _buffer.toString().trim();
        _buffer.clear();
        _resetTimer?.cancel();

        if (code.isNotEmpty && BarcodeValidator.isValid(code)) {
          if (_lastScannedCode == code &&
              _lastScannedTime != null &&
              now.difference(_lastScannedTime!) < const Duration(milliseconds: 500)) {
            return true;
          }
          _lastScannedCode = code;
          _lastScannedTime = now;
          widget.onBarcodeScanned(code);
          return true; // Consume event to prevent accidental submission of focused form
        }
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      if (_lastKeystrokeTime != null &&
          now.difference(_lastKeystrokeTime!).inMilliseconds > _maxInterKeyDelayMs) {
        // Human typing slowly: reset scanner buffer
        _buffer.clear();
      }

      _lastKeystrokeTime = now;
      _buffer.write(char);

      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 250), () {
        _buffer.clear();
      });
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
