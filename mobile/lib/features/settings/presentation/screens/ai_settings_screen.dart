import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/ai_settings_provider.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrlController;
  late TextEditingController _ocrModelController;
  late TextEditingController _visionModelController;
  late TextEditingController _chatModelController;
  late bool _enabled;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settings = ref.read(aiSettingsProvider);
      _enabled = settings.enabled;
      _baseUrlController = TextEditingController(text: settings.baseUrl);
      _ocrModelController = TextEditingController(text: settings.ocrModel);
      _visionModelController = TextEditingController(text: settings.visionModel);
      _chatModelController = TextEditingController(text: settings.chatModel);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _ocrModelController.dispose();
    _visionModelController.dispose();
    _chatModelController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    if (!_enabled || status == 'disabled') return Colors.grey;
    switch (status) {
      case 'ok':
        return AppColors.success;
      case 'degraded':
        return Colors.orange;
      case 'offline':
        return AppColors.danger;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    if (!_enabled || status == 'disabled') return l10n.aiStatusDisabled;
    switch (status) {
      case 'ok':
        return l10n.aiStatusOnline;
      case 'degraded':
        return l10n.aiStatusDegraded;
      case 'offline':
        return l10n.aiStatusOffline;
      default:
        return status.toUpperCase();
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await ref.read(aiSettingsProvider.notifier).checkHealth();
    if (!mounted) return;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.aiConnectionSuccessMessage
              : l10n.aiConnectionFailedMessage(
                  ref.read(aiSettingsProvider).errorMessage ?? l10n.aiStatusOffline,
                ),
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      await ref.read(aiSettingsProvider.notifier).updateConfig(
            enabled: _enabled,
            baseUrl: _baseUrlController.text.trim(),
            ocrModel: _ocrModelController.text.trim(),
            visionModel: _visionModelController.text.trim(),
            chatModel: _chatModelController.text.trim(),
          );
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.aiSettingsSavedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(aiSettingsProvider);
    final statusColor = _getStatusColor(settings.status);
    final statusText = _getStatusText(context, settings.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiSettingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.testAiConnectionAction,
            onPressed: settings.isLoading ? null : _testConnection,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Status Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (settings.isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _testConnection,
                              icon: const Icon(Icons.speed, size: 16),
                              label: Text(l10n.testConnectionAction),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      if (settings.missingModels.isNotEmpty && _enabled) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '${l10n.missingModelsLabel}: ${settings.missingModels.join(', ')}',
                            style: const TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Master Toggle
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile.adaptive(
                  value: _enabled,
                  onChanged: (val) => setState(() => _enabled = val),
                  title: Text(
                    l10n.aiEnabledLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l10n.aiEnabledDescription,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Server URL Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.aiServerUrlLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _baseUrlController,
                        enabled: _enabled,
                        decoration: InputDecoration(
                          hintText: l10n.aiServerUrlHint,
                          prefixIcon: const Icon(Icons.dns_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Base URL cannot be empty';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Model Configuration Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.aiOcrModelLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _ocrModelController,
                        enabled: _enabled,
                        decoration: InputDecoration(
                          hintText: 'glm-ocr',
                          prefixIcon: const Icon(Icons.document_scanner_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.aiVisionModelLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _visionModelController,
                        enabled: _enabled,
                        decoration: InputDecoration(
                          hintText: 'qwen2.5vl:7b',
                          prefixIcon: const Icon(Icons.visibility_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.aiChatModelLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _chatModelController,
                        enabled: _enabled,
                        decoration: InputDecoration(
                          hintText: 'qwen2.5:7b',
                          prefixIcon: const Icon(Icons.chat_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (settings.availableModels.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.availableModelsLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: settings.availableModels.map((m) {
                            return Chip(
                              label: Text(m, style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  l10n.saveAiSettingsAction,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
