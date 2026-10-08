import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/network/api_client.dart';

void main() {
  group('ApiClient URL Normalization & Sanitization', () {
    test('strips accidental /apicd typo and normalizes to /api', () {
      expect(
        ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/apicd'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
    });

    test('appends /api when omitted from root hostname', () {
      expect(
        ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
    });

    test('strips trailing slashes correctly', () {
      expect(
        ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/api/'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
      expect(
        ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com///'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
    });

    test('leaves already correct /api intact', () {
      expect(
        ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/api'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
    });

    test('handles empty or whitespace strings', () {
      expect(ApiClient.normalizeUrl(''), equals(''));
      expect(ApiClient.normalizeUrl('   '), equals(''));
    });
  });
}
