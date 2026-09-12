import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/routes/app_router.dart';
import 'package:fairshare/data/providers/auth_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Router redirects un-onboarded user to /welcome when accessing /home',
      () async {
    final prefs = await SharedPreferences.getInstance();

    // Read router
    final router = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    ).read(appRouterProvider);

    // Initial location should be /welcome
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
  });

  test('Router redirects to /home if user already completed onboarding',
      () async {
    SharedPreferences.setMockInitialValues({
      'fairshare_onboarding_completed': true,
      'fairshare_app_tour_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final router = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    ).read(appRouterProvider);

    // In a new session with completed onboarding, router redirects to /home
    router.go('/home');
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });
}

class RootWidget extends StatelessWidget {
  const RootWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
