import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';
import 'profile_repository.dart';

class AuthRepository {
  final SupabaseService supabaseService;
  final ProfileRepository profileRepository;
  final LocalCacheService cacheService;

  static bool _googleInitialized = false;

  AuthRepository({
    required this.supabaseService,
    required this.profileRepository,
    required this.cacheService,
  });

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : null,
      );
      _googleInitialized = true;
    } catch (_) {
      _googleInitialized = true;
    }
  }

  Stream<AuthState> get authStateChanges =>
      supabaseService.isConfigured
          ? supabaseService.client.auth.onAuthStateChange
          : const Stream.empty();

  User? get currentAuthUser =>
      supabaseService.isConfigured ? supabaseService.client.auth.currentUser : null;

  /// Signs in using native Google Play Services authentication
  Future<UserProfile?> signInWithNativeGoogle() => signInWithGoogle();

  /// Signs in using native Google Play Services authentication
  Future<UserProfile?> signInWithGoogle() async {
    if (!supabaseService.isConfigured) {
      throw Exception('Supabase is not configured.');
    }

    try {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No ID token returned by Google Sign-In.');
      }

      final res = await supabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = res.user;
      if (user == null) {
        throw Exception('Failed to retrieve user from Supabase after Google Sign-In.');
      }

      final fullName = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          user.email?.split('@').first ??
          'User';
      final avatarUrl = user.userMetadata?['avatar_url'] as String? ??
          user.userMetadata?['picture'] as String?;

      // Preserve existing profile details if already created
      final existingProfile = await profileRepository.fetchProfile(user.id);

      final finalFullName = existingProfile?.fullName.isNotEmpty == true
          ? existingProfile!.fullName
          : fullName;
      final finalAvatar = existingProfile?.avatarUrl ?? avatarUrl;

      final updatedProfile = UserProfile(
        id: user.id,
        email: user.email,
        fullName: finalFullName,
        nickname: existingProfile?.nickname,
        username: existingProfile?.username,
        avatarUrl: finalAvatar,
        vpaId: existingProfile?.vpaId,
        phoneNumber: existingProfile?.phoneNumber,
        isGuest: false,
        authProvider: 'google',
        createdAt: existingProfile?.createdAt ?? DateTime.now(),
      );

      await supabaseService.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': finalFullName,
        'nickname': existingProfile?.nickname,
        'username': existingProfile?.username,
        'avatar_url': finalAvatar,
        'vpa_id': existingProfile?.vpaId,
        'is_guest': false,
        'auth_provider': 'google',
      });

      await cacheService.saveCurrentUser(updatedProfile);
      return updatedProfile;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in with email and password
  Future<UserProfile> signInWithEmail(String email, String password) async {
    if (!supabaseService.isConfigured) {
      final user = UserProfile(
        id: 'local_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: email.split('@').first,
        isGuest: false,
        authProvider: 'email',
        createdAt: DateTime.now(),
      );
      await cacheService.saveCurrentUser(user);
      return user;
    }

    try {
      final res = await supabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = res.user;
      if (user == null) {
        throw Exception('No user returned from Supabase sign in.');
      }

      final profile = await profileRepository.fetchProfile(user.id);
      final finalUser = profile ??
          UserProfile(
            id: user.id,
            email: user.email ?? email,
            fullName: email.split('@').first,
            isGuest: false,
            authProvider: 'email',
            createdAt: DateTime.now(),
          );

      await cacheService.saveCurrentUser(finalUser);
      return finalUser;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception(
          'Email not confirmed yet. Please check your email inbox to confirm your account.',
        );
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs up with email, password, and full name
  Future<({UserProfile? user, bool requiresEmailConfirmation})> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    if (!supabaseService.isConfigured) {
      final user = UserProfile(
        id: 'local_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: fullName.trim().isNotEmpty ? fullName : email.split('@').first,
        isGuest: false,
        authProvider: 'email',
        createdAt: DateTime.now(),
      );
      await cacheService.saveCurrentUser(user);
      return (user: user, requiresEmailConfirmation: false);
    }

    try {
      final res = await supabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      final user = res.user;
      if (user == null) {
        return (user: null, requiresEmailConfirmation: true);
      }

      final requiresConfirmation = res.session == null;

      final profile = UserProfile(
        id: user.id,
        email: email,
        fullName: fullName.trim().isNotEmpty ? fullName : email.split('@').first,
        isGuest: false,
        authProvider: 'email',
        createdAt: DateTime.now(),
      );

      await supabaseService.client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': profile.fullName,
        'is_guest': false,
        'auth_provider': 'email',
      });

      await cacheService.saveCurrentUser(profile);
      return (user: profile, requiresEmailConfirmation: requiresConfirmation);
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in as a guest
  Future<UserProfile> signInAsGuest() async {
    if (supabaseService.isConfigured) {
      try {
        final res = await supabaseService.signInAsGuest();
        if (res?.user != null) {
          final guestUser = UserProfile(
            id: res!.user!.id,
            fullName: 'Guest User',
            isGuest: true,
            authProvider: 'guest',
            createdAt: DateTime.now(),
          );
          await supabaseService.client.from('profiles').upsert({
            'id': res.user!.id,
            'full_name': 'Guest User',
            'is_guest': true,
            'auth_provider': 'guest',
          });
          await cacheService.saveCurrentUser(guestUser);
          return guestUser;
        }
      } catch (_) {}
    }

    final cached = cacheService.getCurrentUser();
    if (cached != null && cached.isGuest) return cached;

    final fallback = UserProfile(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      fullName: 'Guest User',
      isGuest: true,
      authProvider: 'guest',
      createdAt: DateTime.now(),
    );
    await cacheService.saveCurrentUser(fallback);
    return fallback;
  }

  /// Resends signup confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    if (!supabaseService.isConfigured) return;
    await supabaseService.client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Signs out of all providers and clears local data
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    if (supabaseService.isConfigured) {
      try {
        await supabaseService.client.auth.signOut();
      } catch (_) {}
    }

    await cacheService.clearAll();
  }
}
