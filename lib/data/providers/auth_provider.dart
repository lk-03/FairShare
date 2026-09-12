import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/supabase_service.dart';

/// Overridden in main.dart once SharedPreferences.getInstance() completes
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalCacheService(prefs);
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final cache = ref.watch(localCacheServiceProvider);
  return ProfileRepository(supabaseService: supabase, cacheService: cache);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localCacheServiceProvider);
  return AuthRepository(
    supabaseService: supabase,
    profileRepository: profileRepo,
    cacheService: cache,
  );
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Manages active authenticated / guest user state
class CurrentUserNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final cache = ref.watch(localCacheServiceProvider);
    return cache.getCurrentUser();
  }

  Future<void> refresh() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final user = await profileRepo.getCurrentProfile();
    state = user;
  }

  Future<void> setUser(UserProfile user) async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.saveCurrentUser(user);
    state = user;
  }

  Future<void> updateProfile({
    String? fullName,
    String? nickname,
    String? username,
    String? avatarUrl,
    String? vpaId,
    String? phoneNumber,
  }) async {
    if (state == null) return;
    final profileRepo = ref.read(profileRepositoryProvider);
    final updated = await profileRepo.updateProfile(
      state!.id,
      fullName: fullName,
      nickname: nickname,
      username: username,
      avatarUrl: avatarUrl,
      vpaId: vpaId,
      phoneNumber: phoneNumber,
    );
    state = updated;
  }

  Future<void> signInWithGoogle() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithGoogle();
    if (user != null) {
      state = user;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithEmail(email, password);
    state = user;
  }

  Future<({UserProfile? user, bool requiresEmailConfirmation})> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    final authRepo = ref.read(authRepositoryProvider);
    final res = await authRepo.signUpWithEmail(email, password, fullName);
    if (res.user != null) {
      state = res.user;
    }
    return res;
  }

  Future<void> signInAsGuest() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInAsGuest();
    state = user;
  }

  Future<void> signOut() async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signOut();
    state = null;
  }
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, UserProfile?>(() {
  return CurrentUserNotifier();
});

/// Tracks onboarding & app tour presentation state
class OnboardingNotifier
    extends Notifier<({bool hasCompletedOnboarding, bool hasSeenAppTour})> {
  @override
  ({bool hasCompletedOnboarding, bool hasSeenAppTour}) build() {
    final cache = ref.watch(localCacheServiceProvider);
    return (
      hasCompletedOnboarding: cache.hasCompletedOnboarding,
      hasSeenAppTour: cache.hasSeenAppTour,
    );
  }

  Future<void> completeOnboarding() async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.setOnboardingCompleted(true);
    state = (
      hasCompletedOnboarding: true,
      hasSeenAppTour: state.hasSeenAppTour,
    );
  }

  Future<void> markAppTourSeen() async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.setAppTourSeen(true);
    state = (
      hasCompletedOnboarding: state.hasCompletedOnboarding,
      hasSeenAppTour: true,
    );
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier,
    ({bool hasCompletedOnboarding, bool hasSeenAppTour})>(() {
  return OnboardingNotifier();
});
