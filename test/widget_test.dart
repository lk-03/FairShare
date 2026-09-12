import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/main.dart';
import 'package:fairshare/data/providers/auth_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FairShareApp smoke test boots router to welcome onboarding',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const FairShareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verifies welcome screen and onboarding carousel render
    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('ALGORITHM POWERED'), findsOneWidget);
  });

  testWidgets('FairShareApp routes to home when onboarding already completed',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'fairshare_onboarding_completed': true,
      'fairshare_app_tour_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const FairShareApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('Nordic Steel • Neo-Fintech Ledger'), findsOneWidget);
    expect(find.text('APPEARANCE (NORDIC STEEL)'), findsOneWidget);
    expect(find.text('ACTIVE COHORT'), findsOneWidget);
  });
}
