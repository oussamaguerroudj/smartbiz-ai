import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import 'ai_settings_model.dart';

class AiSettingsNotifier extends StateNotifier<AiSettingsState> {
  AiSettingsNotifier(this._ref) : super(const AiSettingsState()) {
    _loadFromLocalAndServer();
  }

  final Ref _ref;

  static const _prefEnabled = 'ai_enabled';
  static const _prefBaseUrl = 'ai_base_url';
  static const _prefOcrModel = 'ai_ocr_model';
  static const _prefVisionModel = 'ai_vision_model';
  static const _prefChatModel = 'ai_chat_model';

  Future<void> _loadFromLocalAndServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefEnabled) ?? true;
      final baseUrl = prefs.getString(_prefBaseUrl) ?? 'http://10.0.2.2:11434/v1';
      final ocrModel = prefs.getString(_prefOcrModel) ?? 'glm-ocr';
      final visionModel = prefs.getString(_prefVisionModel) ?? 'qwen2.5vl:7b';
      final chatModel = prefs.getString(_prefChatModel) ?? 'qwen2.5:7b';

      state = state.copyWith(
        enabled: enabled,
        baseUrl: baseUrl,
        ocrModel: ocrModel,
        visionModel: visionModel,
        chatModel: chatModel,
      );

      // Attempt to load live config and health from server
      await refreshConfigAndHealth();
    } catch (e) {
      debugPrint('[AI_SETTINGS] Local load error: $e');
    }
  }

  Future<void> refreshConfigAndHealth() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final client = _ref.read(apiClientProvider);

      // Fetch config from server
      try {
        final configRes = await client.get('/ai/config');
        if (configRes is Map && configRes['data'] is Map) {
          final data = configRes['data'] as Map<String, dynamic>;
          state = state.copyWith(
            enabled: data['enabled'] as bool? ?? state.enabled,
            baseUrl: data['baseUrl'] as String? ?? state.baseUrl,
            ocrModel: data['ocrModel'] as String? ?? state.ocrModel,
            visionModel: data['visionModel'] as String? ?? state.visionModel,
            chatModel: data['chatModel'] as String? ?? state.chatModel,
          );
        }
      } catch (e) {
        debugPrint('[AI_SETTINGS] Server config fetch error: $e');
      }

      // Check health
      await checkHealth();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: 'offline',
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> checkHealth() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final client = _ref.read(apiClientProvider);
      final healthRes = await client.get('/ai/health');
      if (healthRes is Map && healthRes['data'] is Map) {
        final data = healthRes['data'] as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'unknown';
        final availableModels = (data['availableModels'] as List?)?.cast<String>() ?? [];
        final missingModels = (data['missingModels'] as List?)?.cast<String>() ?? [];

        state = state.copyWith(
          status: status,
          availableModels: availableModels,
          missingModels: missingModels,
          isLoading: false,
        );
        return status == 'ok';
      }
      state = state.copyWith(status: 'unknown', isLoading: false);
      return false;
    } catch (e) {
      debugPrint('[AI_SETTINGS] Health check error: $e');
      state = state.copyWith(
        status: 'offline',
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> updateConfig({
    bool? enabled,
    String? baseUrl,
    String? ocrModel,
    String? visionModel,
    String? chatModel,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newEnabled = enabled ?? state.enabled;
      final newBaseUrl = baseUrl?.trim() ?? state.baseUrl;
      final newOcrModel = ocrModel?.trim() ?? state.ocrModel;
      final newVisionModel = visionModel?.trim() ?? state.visionModel;
      final newChatModel = chatModel?.trim() ?? state.chatModel;

      // 1. Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, newEnabled);
      await prefs.setString(_prefBaseUrl, newBaseUrl);
      await prefs.setString(_prefOcrModel, newOcrModel);
      await prefs.setString(_prefVisionModel, newVisionModel);
      await prefs.setString(_prefChatModel, newChatModel);

      state = state.copyWith(
        enabled: newEnabled,
        baseUrl: newBaseUrl,
        ocrModel: newOcrModel,
        visionModel: newVisionModel,
        chatModel: newChatModel,
      );

      // 2. Sync to backend
      final client = _ref.read(apiClientProvider);
      await client.put(
        '/ai/config',
        body: {
          'enabled': newEnabled,
          'baseUrl': newBaseUrl,
          'ocrModel': newOcrModel,
          'visionModel': newVisionModel,
          'chatModel': newChatModel,
        },
      );

      // 3. Re-run health check with new settings
      await checkHealth();
    } catch (e) {
      debugPrint('[AI_SETTINGS] Update config error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}

final aiSettingsProvider = StateNotifierProvider<AiSettingsNotifier, AiSettingsState>(
  (ref) => AiSettingsNotifier(ref),
);
