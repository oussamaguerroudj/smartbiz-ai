import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Shared full-screen barcode scanner — used by both the Sales page
/// ("scan a product straight into the cart") and the Stock page
/// ("scan a product to look it up or add it"). One implementation so
/// both pages get the exact same camera behavior and UI.
///
/// Returns the scanned code (a [String]) via `Navigator.pop`, or `null`
/// if the user backs out / types nothing in the manual-entry fallback.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  // Guards against a single physical scan producing multiple detections
  // (the camera keeps streaming frames) — the very first good read wins
  // and immediately closes the screen.
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(value.trim());
  }

  Future<void> _enterManually() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.manualBarcodeEntryTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(isDense: true),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty && mounted) {
      Navigator.of(context).pop(code.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _PermissionError(
              message: l10n.cameraPermissionRequired,
              onEnterManually: _enterManually,
            ),
          ),
          // Darken everything outside the viewfinder frame so the eye is
          // drawn straight to where the barcode needs to go.
          const _ScannerScrim(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        l10n.barcodeScannerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          final torchOn = state.torchState == TorchState.on;
                          return _RoundIconButton(
                            icon: torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            onPressed: () => _controller.toggleTorch(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.barcodeScannerHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _enterManually,
                  icon: const Icon(Icons.keyboard_outlined, color: Colors.white),
                  label: Text(
                    l10n.enterCodeManually,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark scrim with a cut-out rounded rectangle in the middle — the
/// standard "viewfinder" look for a barcode/QR scanner, built with a
/// single [CustomPainter] rather than four separate positioned boxes so
/// the corner radius stays clean at every screen size.
class _ScannerScrim extends StatelessWidget {
  const _ScannerScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScrimPainter(),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.78;
    final frameHeight = frameWidth * 0.62;
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(20),
    );

    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(frameRRect);
    final combined = Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(combined, scrimPaint);

    // Corner brackets on the viewfinder — a small detail that makes it
    // read instantly as "a scanner" rather than just a rounded box.
    final bracketPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const bracketLen = 22.0;
    const r = 20.0;

    void drawCorner(Offset corner, double dx, double dy) {
      canvas.drawLine(
        corner + Offset(dx * r, 0),
        corner + Offset(dx * (r + bracketLen), 0),
        bracketPaint,
      );
      canvas.drawLine(
        corner + Offset(0, dy * r),
        corner + Offset(0, dy * (r + bracketLen)),
        bracketPaint,
      );
    }

    drawCorner(frameRect.topLeft, 1, 1);
    drawCorner(frameRect.topRight, -1, 1);
    drawCorner(frameRect.bottomLeft, 1, -1);
    drawCorner(frameRect.bottomRight, -1, -1);

    canvas.drawRRect(
      frameRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.message, required this.onEnterManually});
  final String message;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onEnterManually,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            child: Text(l10n.enterCodeManually),
          ),
        ],
      ),
    );
  }
}

