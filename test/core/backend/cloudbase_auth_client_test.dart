import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';

void main() {
  group('normalizeCloudBasePhoneNumber', () {
    test('adds +86 prefix for mainland China numbers', () {
      expect(normalizeCloudBasePhoneNumber('13800138000'), '+86 13800138000');
    });

    test('keeps an already normalized phone number', () {
      expect(
        normalizeCloudBasePhoneNumber('+86 13800138000'),
        '+86 13800138000',
      );
    });

    test('normalizes explicit country code with dash separator', () {
      expect(
        normalizeCloudBasePhoneNumber('+86-13800138000'),
        '+86 13800138000',
      );
    });
  });
}
