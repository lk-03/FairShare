import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/profile.dart';
import '../../core/widgets/fairshare_bottom_nav.dart';
import '../../data/providers/auth_provider.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// RouterNotifier bridges Riverpod state changes to GoRouter's refreshListenable.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<({bool hasCompletedOnboarding, bool hasSeenAppTour})>(
      onboardingProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<UserProfile?>(
      currentUserProvider,
      (_, _) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: notifier,
    redirect: (context, state) {
      final onboarding = ref.read(onboardingProvider);
      final hasCompleted = onboarding.hasCompletedOnboarding;
      final location = state.matchedLocation;
      final isTour = state.uri.queryParameters['mode'] == 'tour';

      final isAuthRoute =
          location == '/welcome' || location == '/login' || location == '/signup';

      if (!hasCompleted) {
        // User hasn't finished onboarding: must be on welcome/auth routes
        if (!isAuthRoute) return '/welcome';
        return null;
      }

      // User has completed onboarding: redirect away from auth routes unless tour mode
      if (isAuthRoute && !isTour) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return WelcomeScreen(mode: mode);
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => AuthScreen(
          initialMode: AuthMode.emailSignIn,
          onAuthenticated: (data) async {
            await ref.read(onboardingProvider.notifier).completeOnboarding();
            if (context.mounted) context.go('/home');
          },
          onBack: () => context.go('/welcome'),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => AuthScreen(
          initialMode: AuthMode.emailSignUp,
          onAuthenticated: (data) async {
            if (data.isNewUser) {
              context.go('/welcome');
            } else {
              await ref.read(onboardingProvider.notifier).completeOnboarding();
              if (context.mounted) context.go('/home');
            }
          },
          onBack: () => context.go('/welcome'),
        ),
      ),
      GoRoute(
        path: '/groups/:id',
        name: 'group-detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GroupDetailScreen(groupId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: FairShareBottomNav(
              currentIndex: navigationShell.currentIndex,
              onTabSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                name: 'groups',
                builder: (context, state) =>
                    const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                name: 'activity',
                builder: (context, state) =>
                    const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
