import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/features/onboarding/presentation/widgets/onboarding_carousel.dart';

void main() {
  Widget buildTestWidget({
    required VoidCallback onComplete,
    required VoidCallback onSkip,
  }) {
    return MaterialApp(
      theme: AppTheme.buildTheme(brightness: Brightness.dark),
      home: Scaffold(
        body: OnboardingCarousel(
          onComplete: onComplete,
          onSkip: onSkip,
        ),
      ),
    );
  }

  testWidgets('OnboardingCarousel renders initial slide and triggers onSkip',
      (tester) async {
    bool skipTriggered = false;
    bool completeTriggered = false;

    await tester.pumpWidget(
      buildTestWidget(
        onComplete: () => completeTriggered = true,
        onSkip: () => skipTriggered = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('ALGORITHM POWERED'), findsOneWidget);
    expect(find.text('Split Smarter,\nSettle Faster'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(skipTriggered, isTrue);
    expect(completeTriggered, isFalse);
  });

  testWidgets('OnboardingCarousel advances through slides and finishes on Get Started',
      (tester) async {
    bool completeTriggered = false;

    await tester.pumpWidget(
      buildTestWidget(
        onComplete: () => completeTriggered = true,
        onSkip: () {},
      ),
    );
    await tester.pumpAndSettle();

    // Slide 1 -> Slide 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('INSTANT & ZERO FEES'), findsOneWidget);

    // Slide 2 -> Slide 3
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('FLEXIBLE MATH'), findsOneWidget);

    // Slide 3 -> Slide 4
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('HOUSEHOLD & TRIPS'), findsOneWidget);

    // Slide 4 -> Slide 5 (Last slide)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('EASY MIGRATION'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(completeTriggered, isTrue);
  });
}
