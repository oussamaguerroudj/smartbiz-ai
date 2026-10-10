import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/glass_panel.dart';

/// Desktop split-screen layout for Login & Register screens.
/// Left 45%: Brand showcase, value props, enterprise features
/// Right 55%: Centered glassmorphic card for the authentication form
class DesktopAuthScaffold extends StatelessWidget {
  const DesktopAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AmbientBackground(
        child: Row(
          children: [
            // Left 45%: Enterprise Showcase
            Expanded(
              flex: 45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.cyberNavy,
                            AppColors.surfaceElevatedDark,
                            AppColors.surfacePanelDark,
                          ]
                        : [
                            const Color(0xFF1E293B),
                            const Color(0xFF0F172A),
                            const Color(0xFF0A0F1D),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    right: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: AppColors.aiGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricBlue.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modiri AI',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'ENTERPRISE SUITE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.electricBlue,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Value Propositions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildFeaturePill(
                          Icons.speed_rounded,
                          'Sub-second POS & Multi-Cart Sessions',
                          'Process transactions without interruptions or queue delays.',
                        ),
                        const SizedBox(height: 20),
                        _buildFeaturePill(
                          Icons.analytics_outlined,
                          'Live Financial & Inventory Intelligence',
                          'Deterministic reporting with real-time stock valuation.',
                        ),
                        const SizedBox(height: 20),
                        _buildFeaturePill(
                          Icons.cloud_sync_outlined,
                          'Airtight Tenant Isolation & Offline-First',
                          'Safeguarded company data with automatic synchronization.',
                        ),
                      ],
                    ),

                    // Legal / Compliance Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '© 2026 Modiri AI. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.successGreen,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Systems Nominal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right 55%: Centered Glassmorphic Form Card
            Expanded(
              flex: 55,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      borderRadius: BorderRadius.circular(20),
                      borderColor: isDark ? Colors.white.withValues(alpha: 0.12) : null,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: AppColors.electricBlue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
