import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desktop_components.dart';
import '../../../core/widgets/glass_panel.dart';

class DesktopSettingsScreen extends ConsumerStatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  ConsumerState<DesktopSettingsScreen> createState() =>
      _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends ConsumerState<DesktopSettingsScreen> {
  final _apiUrlController = TextEditingController();
  String _connectionStatus = '';
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = ApiClient.baseUrl;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = '';
    });

    final url = _apiUrlController.text.trim();
    ApiClient.setCustomBaseUrl(url);

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/health');
      setState(() {
        _isTesting = false;
        _connectionStatus = 'Connection Successful: Server is healthy ($res)';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _connectionStatus = 'Connection Failed: $e';
      });
    }
  }

  Future<void> _saveApiUrl() async {
    final url = _apiUrlController.text.trim();
    await ApiClient.persistCustomUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API URL saved successfully'),
          backgroundColor: AppColors.neonEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: ListView(
        children: [
          const DesktopPageHeader(
            title: 'System Settings & Preferences',
            subtitle: 'Configure backend networking, hardware peripherals, and account preferences.',
          ),

          // 1. Backend API Configuration
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_outlined, color: AppColors.electricBlue, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Backend Server Connection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Windows desktop client communicates directly with your Render Node.js backend & PostgreSQL database.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiUrlController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          prefixIcon: Icon(Icons.link, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyberNavyDeep),
                            )
                          : const Text('Test Ping'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saveApiUrl,
                      child: const Text('Save URL'),
                    ),
                  ],
                ),
                if (_connectionStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _connectionStatus.contains('Successful')
                          ? AppColors.neonEmerald
                          : AppColors.neonRose,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Hardware Peripherals
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print_outlined, color: AppColors.electricBlue, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'POS Hardware Configuration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingRow(
                  title: 'ESC/POS Thermal Receipt Paper Size',
                  description: 'Default width for sales receipt printing',
                  trailing: const DesktopBadge(label: '80mm Standard', color: AppColors.electricBlue),
                ),
                const Divider(color: AppColors.borderDark),
                _buildSettingRow(
                  title: 'Barcode Scanner Input Mode',
                  description: 'Hardware USB scanner acts as keyboard emulator',
                  trailing: const DesktopBadge(label: 'HID Keyboard', color: AppColors.neonEmerald),
                ),
                const Divider(color: AppColors.borderDark),
                _buildSettingRow(
                  title: 'Invoice PDF Rendering Engine',
                  description: 'Embedded Cairo TTF with Arabic RTL shaping',
                  trailing: const DesktopBadge(label: 'Cairo TrueType', color: AppColors.cyanAccent),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Multi-Tenant Session & Security
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.electricBlue, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Tenant & Account Security',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingRow(
                  title: 'Active Company Tenant',
                  description: 'All local queries, sync actions, and reports are isolated by this ID',
                  trailing: Text(session.companyId ?? 'comp_1', style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: AppColors.borderDark),
                _buildSettingRow(
                  title: 'Current User Email',
                  description: 'Signed in operator',
                  trailing: Text(session.userEmail ?? 'admin@modiriai.com', style: const TextStyle(color: AppColors.textPrimary)),
                ),
                const Divider(color: AppColors.borderDark),
                _buildSettingRow(
                  title: 'Session Token Storage',
                  description: 'Windows Data Protection API (DPAPI) via Flutter Secure Storage',
                  trailing: const DesktopBadge(label: 'Windows DPAPI Encrypted', color: AppColors.neonEmerald),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => ref.read(sessionProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sign Out of Application'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonRose,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({required String title, required String description, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
