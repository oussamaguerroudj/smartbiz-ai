import 'package:flutter/services.dart';

typedef BarcodeScanCallback = void Function(String barcode);

/// External USB and Bluetooth barcode scanner handler for Windows desktop.
/// Operates on hardware HID keyboard emulation mode.
class BarcodeScannerHandler {
  final BarcodeScanCallback onScan;
  final Duration interKeyTimeout;
  final Duration duplicateScanCooldown;

  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyTime;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  BarcodeScannerHandler({
    required this.onScan,
    this.interKeyTimeout = const Duration(milliseconds: 150),
    this.duplicateScanCooldown = const Duration(milliseconds: 500),
  });

  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter ||
        logicalKey == LogicalKeyboardKey.tab) {
      if (_buffer.isNotEmpty) {
        final code = _buffer.toString().trim();
        _buffer.clear();
        _lastKeyTime = null;

        _processCompletedScan(code);
        return true;
      }
      return false;
    }

    if (_lastKeyTime != null && now.difference(_lastKeyTime!) > interKeyTimeout) {
      _buffer.clear();
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32 && char.codeUnitAt(0) != 127) {
      _buffer.write(char);
      _lastKeyTime = now;
      return false;
    }

    return false;
  }

  void manualSubmit(String raw) {
    final code = raw.trim();
    if (code.isNotEmpty) {
      _processCompletedScan(code);
    }
  }

  void _processCompletedScan(String code) {
    final now = DateTime.now();
    if (_lastScannedCode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < duplicateScanCooldown) {
      return;
    }

    _lastScannedCode = code;
    _lastScannedTime = now;
    onScan(code);
  }

  void clear() {
    _buffer.clear();
    _lastKeyTime = null;
  }
}
