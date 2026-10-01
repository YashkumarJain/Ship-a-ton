import 'package:flutter/foundation.dart';

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const revenueCatTestKey =
      String.fromEnvironment('REVENUECAT_TEST_API_KEY');
  static const revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
  static const revenueCatEntitlement = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'premium',
  );

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String revenueCatKeyForPlatform() {
    if (kDebugMode && revenueCatTestKey.isNotEmpty) return revenueCatTestKey;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return revenueCatIosKey;
      case TargetPlatform.android:
        return revenueCatAndroidKey;
      default:
        return '';
    }
  }
}
