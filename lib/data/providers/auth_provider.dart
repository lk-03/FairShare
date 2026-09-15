import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/expense.dart';
import '../../core/models/group.dart';
import '../../core/models/group_member.dart';
import '../../core/models/profile.dart';
import '../../core/models/split.dart';
import '../local/local_cache_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/push_notification_service.dart';
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
    final user = cache.getCurrentUser();
    if (user != null) {
      PushNotificationService.syncDeviceToken(user.id);
    }
    return user;
  }

  Future<void> refresh() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final user = await profileRepo.getCurrentProfile();
    state = user;
    PushNotificationService.syncDeviceToken(user.id);
  }

  Future<void> setUser(UserProfile user) async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.saveCurrentUser(user);
    state = user;
    PushNotificationService.syncDeviceToken(user.id);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.saveCurrentUser(profile);
    final profileRepo = ref.read(profileRepositoryProvider);
    await profileRepo.upsertProfile(profile);
    state = profile;
    PushNotificationService.syncDeviceToken(profile.id);
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
    PushNotificationService.syncDeviceToken(updated.id);
  }

  Future<void> signInWithGoogle() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithGoogle();
    if (user != null) {
      state = user;
      PushNotificationService.syncDeviceToken(user.id);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInWithEmail(email, password);
    state = user;
    PushNotificationService.syncDeviceToken(user.id);
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

  /// One-tap demo / test login that prepares a rich test profile and seeds sample ledger data
  Future<void> signInAsDemoUser() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.signInAsGuest();
    final demoProfile = UserProfile(
      id: user.id,
      email: 'alex.vance@fairshare.app',
      fullName: 'Alex Vance',
      nickname: 'Alex',
      username: 'alexv',
      vpaId: 'alex@okaxis',
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=Alex',
      isGuest: true,
      authProvider: 'demo',
      createdAt: DateTime.now(),
    );
    final cache = ref.read(localCacheServiceProvider);
    await cache.saveCurrentUser(demoProfile);
    state = demoProfile;

    // Seed sample group & expenses if local cache is empty
    final cachedGroups = cache.getCachedGroups();
    if (cachedGroups.isEmpty) {
      final sampleGroup = Group(
        id: 'cohort_demo_402',
        name: 'Flat 402 - Bangalore',
        description: 'Roommates monthly split & groceries',
        category: 'house',
        currency: 'INR',
        createdBy: demoProfile.id,
        inviteCode: 'FLAT402',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: [
          GroupMember(
            id: 'gm_demo_1',
            cohortId: 'cohort_demo_402',
            userId: demoProfile.id,
            role: 'admin',
            joinedAt: DateTime.now(),
            profile: demoProfile,
          ),
          GroupMember(
            id: 'gm_demo_2',
            cohortId: 'cohort_demo_402',
            userId: 'user_sam_demo',
            role: 'member',
            joinedAt: DateTime.now(),
            profile: UserProfile(
              id: 'user_sam_demo',
              fullName: 'Sam Altman',
              email: 'sam@fairshare.app',
              vpaId: 'sam@okhdfcbank',
              createdAt: DateTime.now(),
            ),
          ),
        ],
      );

      final sampleExpense = Expense(
        id: 'exp_demo_1',
        cohortId: 'cohort_demo_402',
        title: 'Weekly Groceries & Supplies',
        category: 'dining',
        totalAmount: 1200.0,
        paidByUserId: demoProfile.id,
        paidByName: demoProfile.fullName,
        currency: 'INR',
        splits: [
          ExpenseSplit(userId: demoProfile.id, amount: 600.0),
          ExpenseSplit(userId: 'user_sam_demo', amount: 600.0),
        ],
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

      await cache.saveGroups([sampleGroup]);
      await cache.saveExpenses('cohort_demo_402', [sampleExpense]);
    }
  }

  Future<void> signOut() async {
    final currentId = state?.id;
    if (currentId != null) {
      await PushNotificationService.clearDeviceToken(currentId);
    }
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

  Future<void> resetOnboarding() async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.setOnboardingCompleted(false);
    state = (
      hasCompletedOnboarding: false,
      hasSeenAppTour: state.hasSeenAppTour,
    );
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier,
    ({bool hasCompletedOnboarding, bool hasSeenAppTour})>(() {
  return OnboardingNotifier();
});
