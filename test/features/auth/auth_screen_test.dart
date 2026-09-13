import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/features/auth/presentation/screens/auth_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    AuthMode initialMode = AuthMode.options,
    ValueChanged<AuthSuccessData>? onAuthenticated,
    VoidCallback? onBack,
    SharedPreferences? prefs,
  }) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: AuthScreen(
          initialMode: initialMode,
          onAuthenticated: onAuthenticated,
          onBack: onBack,
        ),
      ),
    );
  }

  testWidgets('AuthScreen renders options view by default and switches to Email Sign In',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(
        initialMode: AuthMode.options,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FairShare'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsNothing);
    expect(find.text('New to FairShare? Create an Account'), findsOneWidget);

    // Tap Continue with Email
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Email'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('AuthScreen switches between Email Sign In and Email Sign Up',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(
        initialMode: AuthMode.emailSignIn,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Email'), findsOneWidget);
    expect(find.text('FULL NAME'), findsNothing);

    // Switch to Sign Up
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    expect(find.text('Create FairShare Account'), findsOneWidget);
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('AuthScreen back button returns to options from email sign in',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildTestWidget(
        initialMode: AuthMode.emailSignIn,
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Email'), findsOneWidget);

    // Tap back icon button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FairShare'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsNothing);
  });
}
