import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AppConfig centralizes all environmental variables and backend endpoints
class AppConfig {
  static const String defaultSupabaseUrl =
      'https://axjmjggkqbwnibgkosaw.supabase.co';
  static const String defaultSupabaseAnonKey =
      'sb_publishable_b42lq6WD2QGAFMVQmMgg2A_ZhmR0man';
  static const String defaultGoogleWebClientId =
      '256502909999-si4tkiianf71fhdgon0f1d2oa79pn688.apps.googleusercontent.com';
  static const String defaultGeminiApiKey = '';

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env file not present or not bundled in assets; will use defaults
    }
  }

  static String get supabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (dotenv.isInitialized) {
      return dotenv.env['SUPABASE_URL'] ??
          dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ??
          defaultSupabaseUrl;
    }
    return defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;
    if (dotenv.isInitialized) {
      return dotenv.env['SUPABASE_ANON_KEY'] ??
          dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ??
          defaultSupabaseAnonKey;
    }
    return defaultSupabaseAnonKey;
  }

  static String get googleWebClientId {
    const envId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (envId.isNotEmpty) return envId;
    if (dotenv.isInitialized) {
      return dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
          dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'] ??
          defaultGoogleWebClientId;
    }
    return defaultGoogleWebClientId;
  }

  static String? get geminiApiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    if (dotenv.isInitialized) {
      final key = dotenv.env['GEMINI_API_KEY'] ??
          dotenv.env['EXPO_PUBLIC_GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    }
    return defaultGeminiApiKey;
  }

  static bool get isSupabaseConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.isNotEmpty &&
        !url.contains('placeholder') &&
        key.isNotEmpty &&
        !key.contains('placeholder');
  }
}
