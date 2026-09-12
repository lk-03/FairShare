import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/profile.dart';
import '../../core/widgets/theme_gradient_header.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/groups_provider.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

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
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
    ],
  );
});

/// HomePlaceholderScreen provides an immediate landing surface after completing
/// authentication, displaying user profile state, active group, theme controls,
/// and tour replay until Phase 4 implements the bottom navigation shell.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    final groups = ref.watch(groupsProvider);
    final activeGroup = ref.watch(activeGroupProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    final groupsCount = groups.value?.length ?? 0;
    String displayName = 'FairShare Member';
    if (user != null) {
      if (user.fullName.isNotEmpty) {
        displayName = user.fullName;
      } else if (user.nickname != null && user.nickname!.isNotEmpty) {
        displayName = user.nickname!;
      }
    }

    return Scaffold(
      backgroundColor: colors.screen,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThemeGradientHeader(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FairShare',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nordic Steel • Neo-Fintech Ledger',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.help_outline_rounded, color: colors.textMain),
                    tooltip: 'Replay App Tour',
                    onPressed: () => context.push('/welcome?mode=tour'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Profile Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.cyan, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: user?.avatarUrl != null &&
                                  user!.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: colors.accentPill,
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: colors.cyan,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colors.accentPill,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: colors.cyan,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'Offline Guest Session',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (user?.vpaId != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.vpaId!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colors.cyan,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user?.isGuest == true ? 'GUEST' : 'SYNCED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: colors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cohort / Group Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ACTIVE COHORT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: colors.cyan,
                              ),
                            ),
                            Text(
                              '$groupsCount Groups',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeGroup?.name ?? 'Flat 402 - Bangalore',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invite Code: ${activeGroup?.inviteCode ?? "BLR402"} • ${activeGroup?.currency ?? "INR"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Theme Appearance Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APPEARANCE (NORDIC STEEL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: colors.cyan,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 16),
                              label: Text('Auto'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 16),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 16),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (set) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(set.first);
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colors.cyan.withValues(alpha: 0.2);
                              }
                              return colors.accentPill;
                            }),
                            foregroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colors.cyan;
                              }
                              return colors.textSecondary;
                            }),
                            side: WidgetStateProperty.all(
                              BorderSide(color: colors.border, width: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(currentUserProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/welcome');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colors.red.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(Icons.logout_rounded, size: 18, color: colors.red),
                    label: Text(
                      'Sign Out of FairShare',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
