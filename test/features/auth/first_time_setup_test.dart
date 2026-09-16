import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/features/auth/presentation/screens/first_time_setup_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    String? initialName,
    String? initialEmail,
    required VoidCallback onFinish,
    SharedPreferences? prefs,
  }) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: FirstTimeSetupScreen(
          initialName: initialName,
          initialEmail: initialEmail,
          onFinish: onFinish,
        ),
      ),
    );
  }

  testWidgets('FirstTimeSetupScreen renders form fields and populates initials',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    bool finished = false;

    await tester.pumpWidget(
      buildTestWidget(
        initialName: 'Kiran Rao',
        initialEmail: 'kiran@example.com',
        onFinish: () => finished = true,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customize Profile'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('NICKNAME / DISPLAY NAME'), findsOneWidget);
    expect(find.text('USERNAME HANDLE (@)'), findsOneWidget);
    expect(find.text('UPI ID (FOR INSTANT SETTLEMENTS)'), findsOneWidget);
    expect(find.text('Migrating from Splitwise?'), findsOneWidget);

    // Verify initial values
    expect(find.text('Kiran Rao'), findsOneWidget);
    expect(find.text('kiran_rao'), findsOneWidget);

    // Tap UPI chip
    await tester.tap(find.text('@okhdfcbank'));
    await tester.pumpAndSettle();

    expect(find.text('kiranrao@okhdfcbank'), findsOneWidget);

    // Complete setup
    await tester.tap(find.text('Complete Setup & Start'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('FirstTimeSetupScreen skip for now immediately triggers onFinish',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    bool finished = false;

    await tester.pumpWidget(
      buildTestWidget(
        onFinish: () => finished = true,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });
}
