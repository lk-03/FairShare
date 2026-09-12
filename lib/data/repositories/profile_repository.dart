import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';

final UserProfile defaultGuestUser = UserProfile(
  id: 'guest_user_default',
  fullName: 'You',
  email: '',
  isGuest: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

class ProfileRepository {
  final SupabaseService supabaseService;
  final LocalCacheService cacheService;

  ProfileRepository({
    required this.supabaseService,
    required this.cacheService,
  });

  /// Fetches user profile by ID from Supabase with graceful fallback
  Future<UserProfile?> fetchProfile(String userId) async {
    if (!supabaseService.isConfigured || !isUuid(userId)) {
      final cached = cacheService.getCurrentUser();
      if (cached != null && cached.id == userId) return cached;
      return null;
    }

    try {
      final data = await supabaseService.client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      final profile = UserProfile.fromJson(data);
      // If this is the current active session user, update local cache
      final currentSessionUser = supabaseService.client.auth.currentUser;
      if (currentSessionUser != null && currentSessionUser.id == userId) {
        await cacheService.saveCurrentUser(profile);
      }
      return profile;
    } catch (_) {
      final cached = cacheService.getCurrentUser();
      if (cached != null && cached.id == userId) return cached;
      return null;
    }
  }

  /// Updates or upserts profile in Supabase & local cache
  Future<UserProfile> updateProfile(
    String userId, {
    String? fullName,
    String? nickname,
    String? username,
    String? avatarUrl,
    String? vpaId,
    String? phoneNumber,
    bool? isGuest,
    String? authProvider,
  }) async {
    final cached = cacheService.getCurrentUser() ??
        UserProfile(
          id: userId,
          fullName: fullName ?? 'You',
          createdAt: DateTime.now(),
        );

    final updated = cached.copyWith(
      fullName: fullName,
      nickname: nickname,
      username: username,
      avatarUrl: avatarUrl,
      vpaId: vpaId,
      phoneNumber: phoneNumber,
      isGuest: isGuest,
      authProvider: authProvider,
    );

    await cacheService.saveCurrentUser(updated);

    if (!supabaseService.isConfigured) {
      return updated;
    }

    final activeUser = supabaseService.client.auth.currentUser;
    final effectiveUserId = activeUser?.id ?? userId;

    if (!isUuid(effectiveUserId)) {
      return updated;
    }

    final dbPayload = <String, dynamic>{
      'full_name': ?fullName,
      'nickname': ?nickname,
      'username': ?username,
      'avatar_url': ?avatarUrl,
      'vpa_id': ?vpaId,
      'phone_number': ?phoneNumber,
      'is_guest': ?isGuest,
      'auth_provider': ?authProvider,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final updatedData = await supabaseService.client
          .from('profiles')
          .update(dbPayload)
          .eq('id', effectiveUserId)
          .select()
          .maybeSingle();

      if (updatedData != null) {
        final saved = UserProfile.fromJson(updatedData);
        await cacheService.saveCurrentUser(saved);
        return saved;
      }

      // If record not found, upsert with defaults
      final upsertPayload = <String, dynamic>{
        'id': effectiveUserId,
        'full_name': fullName?.trim().isNotEmpty == true
            ? fullName!
            : (nickname?.trim().isNotEmpty == true ? nickname! : 'You'),
        'is_guest': isGuest ?? true,
        'auth_provider': authProvider ?? 'guest',
        ...dbPayload,
      };

      final upsertData = await supabaseService.client
          .from('profiles')
          .upsert(upsertPayload)
          .select()
          .maybeSingle();

      if (upsertData != null) {
        final saved = UserProfile.fromJson(upsertData);
        await cacheService.saveCurrentUser(saved);
        return saved;
      }
    } catch (_) {
      // Retain local cached version on network error
    }

    return updated;
  }

  /// Retrieves or initializes the current active user profile
  Future<UserProfile> getCurrentProfile() async {
    final cached = cacheService.getCurrentUser();

    if (!supabaseService.isConfigured) {
      return cached ?? defaultGuestUser;
    }

    try {
      final authUser = supabaseService.client.auth.currentUser;
      if (authUser != null) {
        final live = await fetchProfile(authUser.id);
        if (live != null) return live;

        final metaName = authUser.userMetadata?['full_name'] as String? ??
            authUser.userMetadata?['name'] as String? ??
            authUser.email?.split('@').first ??
            'You';

        final avatarUrl = authUser.userMetadata?['avatar_url'] as String? ??
            authUser.userMetadata?['picture'] as String?;

        final newProfile = UserProfile(
          id: authUser.id,
          email: authUser.email,
          fullName: metaName,
          avatarUrl: avatarUrl,
          isGuest: false,
          authProvider: authUser.appMetadata['provider'] as String? ?? 'email',
          createdAt: DateTime.now(),
        );

        await supabaseService.client.from('profiles').upsert({
          'id': authUser.id,
          'email': authUser.email,
          'full_name': metaName,
          'avatar_url': avatarUrl,
          'is_guest': false,
          'auth_provider': authUser.appMetadata['provider'] ?? 'email',
        });

        await cacheService.saveCurrentUser(newProfile);
        return newProfile;
      }
    } catch (_) {}

    return cached ?? defaultGuestUser;
  }
}
