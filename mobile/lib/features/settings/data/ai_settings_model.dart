import 'package:flutter/foundation.dart';

@immutable
class AiSettingsState {
  const AiSettingsState({
    this.enabled = true,
    this.baseUrl = 'http://10.0.2.2:11434/v1',
    this.ocrModel = 'glm-ocr',
    this.visionModel = 'qwen2.5vl:7b',
    this.chatModel = 'qwen2.5:7b',
    this.status = 'unknown',
    this.availableModels = const [],
    this.missingModels = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final bool enabled;
  final String baseUrl;
  final String ocrModel;
  final String visionModel;
  final String chatModel;
  final String status; // 'unknown', 'ok', 'degraded', 'offline', 'disabled'
  final List<String> availableModels;
  final List<String> missingModels;
  final bool isLoading;
  final String? errorMessage;

  AiSettingsState copyWith({
    bool? enabled,
    String? baseUrl,
    String? ocrModel,
    String? visionModel,
    String? chatModel,
    String? status,
    List<String>? availableModels,
    List<String>? missingModels,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiSettingsState(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      ocrModel: ocrModel ?? this.ocrModel,
      visionModel: visionModel ?? this.visionModel,
      chatModel: chatModel ?? this.chatModel,
      status: status ?? this.status,
      availableModels: availableModels ?? this.availableModels,
      missingModels: missingModels ?? this.missingModels,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
