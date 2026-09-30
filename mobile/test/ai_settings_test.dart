import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/settings/data/ai_settings_model.dart';

void main() {
  group('AiSettingsState Tests', () {
    test('Default values are correct', () {
      const state = AiSettingsState();
      expect(state.enabled, isTrue);
      expect(state.baseUrl, 'http://10.0.2.2:11434/v1');
      expect(state.ocrModel, 'glm-ocr');
      expect(state.visionModel, 'qwen2.5vl:7b');
      expect(state.chatModel, 'qwen2.5:7b');
      expect(state.status, 'unknown');
      expect(state.availableModels, isEmpty);
      expect(state.missingModels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates fields accurately', () {
      const state = AiSettingsState();
      final updated = state.copyWith(
        enabled: false,
        baseUrl: 'http://localhost:11434/v1',
        ocrModel: 'paddleocr',
        status: 'ok',
        availableModels: ['glm-ocr', 'qwen2.5vl:7b'],
        isLoading: true,
      );

      expect(updated.enabled, isFalse);
      expect(updated.baseUrl, 'http://localhost:11434/v1');
      expect(updated.ocrModel, 'paddleocr');
      expect(updated.visionModel, 'qwen2.5vl:7b'); // unchanged
      expect(updated.status, 'ok');
      expect(updated.availableModels.length, 2);
      expect(updated.isLoading, isTrue);
    });

    test('copyWith handles error message clearing', () {
      final state = const AiSettingsState().copyWith(errorMessage: 'Connection error');
      expect(state.errorMessage, 'Connection error');

      final cleared = state.copyWith(errorMessage: null);
      expect(cleared.errorMessage, isNull);
    });
  });
}
