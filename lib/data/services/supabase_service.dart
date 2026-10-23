import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Validates whether a given string is a valid UUID format
bool isUuid(String? id) {
  if (id == null || id.isEmpty) return false;
  return _uuidRegex.hasMatch(id);
}

/// Service managing Supabase client initialization, lifecycle and configuration
class SupabaseService {
  static bool _initialized = false;

  /// Initializes Supabase if configured and not yet initialized
  static Future<void> initialize() async {
    if (_initialized) return;

    if (AppConfig.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
          debug: false,
        );
        _initialized = true;
      } catch (e) {
        // May already be initialized in test or hot restart
        _initialized = true;
      }
    }
  }

  static bool get isInitialized => _initialized;

  /// Whether Supabase is configured with non-placeholder credentials and has been initialized
  bool get isConfigured => AppConfig.isSupabaseConfigured && _initialized;

  /// Returns the underlying SupabaseClient
  SupabaseClient get client => Supabase.instance.client;

  /// Performs anonymous sign in (Guest mode)
  Future<AuthResponse?> signInAsGuest() async {
    if (!isConfigured) return null;
    try {
      return await client.auth.signInAnonymously();
    } catch (_) {
      return null;
    }
  }
}
