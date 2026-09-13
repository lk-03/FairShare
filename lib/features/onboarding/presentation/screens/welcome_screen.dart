import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../auth/presentation/screens/first_time_setup_screen.dart';
import '../widgets/onboarding_carousel.dart';

enum WelcomeStep {
  carousel,
  auth,
  setup,
}

/// WelcomeScreen orchestrates the first-time user onboarding journey:
/// 1. Interactive 5-slide feature carousel.
/// 2. Authentication (Google, Email).
/// 3. Profile customization (avatar, nickname, @username, UPI VPA).
///
/// Also supports `mode=tour` to replay the carousel without forcing authentication.
class WelcomeScreen extends ConsumerStatefulWidget {
  final String? mode;

  const WelcomeScreen({
    super.key,
    this.mode,
  });

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late WelcomeStep _step;
  AuthSuccessData? _authData;

  bool get isTourOnly => widget.mode == 'tour';

  @override
  void initState() {
    super.initState();
    final onboarding = ref.read(onboardingProvider);
    if (isTourOnly) {
      _step = WelcomeStep.carousel;
    } else if (onboarding.hasSeenAppTour) {
      _step = WelcomeStep.auth;
    } else {
      _step = WelcomeStep.carousel;
    }
  }

  Future<void> _handleTourDismiss() async {
    await ref.read(onboardingProvider.notifier).markAppTourSeen();
    if (!mounted) return;

    if (isTourOnly) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      setState(() => _step = WelcomeStep.auth);
    }
  }

  Future<void> _handleAuthenticated(AuthSuccessData data) async {
    _authData = data;

    if (data.isNewUser == false) {
      // Existing user: mark onboarding complete and route to home
      await ref.read(onboardingProvider.notifier).completeOnboarding();
      await ref.read(onboardingProvider.notifier).markAppTourSeen();
      if (!mounted) return;

      if (isTourOnly) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      } else {
        context.go('/home');
      }
      return;
    }

    // New user: proceed to first time profile setup
    setState(() => _step = WelcomeStep.setup);
  }

  Future<void> _handleFinishSetup() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    await ref.read(onboardingProvider.notifier).markAppTourSeen();
    if (!mounted) return;

    if (isTourOnly) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case WelcomeStep.carousel:
        return Scaffold(
          body: OnboardingCarousel(
            onComplete: _handleTourDismiss,
            onSkip: _handleTourDismiss,
          ),
        );

      case WelcomeStep.auth:
        return AuthScreen(
          onAuthenticated: _handleAuthenticated,
          onBack: isTourOnly
              ? () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                }
              : () => setState(() => _step = WelcomeStep.carousel),
        );

      case WelcomeStep.setup:
        return FirstTimeSetupScreen(
          initialName: _authData?.fullName,
          initialEmail: _authData?.email,
          onFinish: _handleFinishSetup,
        );
    }
  }
}
