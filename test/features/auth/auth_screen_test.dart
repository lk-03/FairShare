import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/repositories/auth_repository.dart';
import 'package:fairshare/data/repositories/profile_repository.dart';
import 'package:fairshare/data/services/supabase_service.dart';
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

  testWidgets('AuthScreen tapping Demo Login signs in and triggers onAuthenticated',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    AuthSuccessData? authResult;

    await tester.pumpWidget(
      buildTestWidget(
        initialMode: AuthMode.options,
        prefs: prefs,
        onAuthenticated: (data) => authResult = data,
      ),
    );
    await tester.pumpAndSettle();

    final demoButton = find.byKey(const Key('demo_login_button'));
    expect(demoButton, findsOneWidget);
    expect(find.text('One-Tap Demo Login (Testing)'), findsOneWidget);

    await tester.tap(demoButton);
    await tester.pumpAndSettle();

    expect(authResult, isNotNull);
    expect(authResult!.provider, 'demo');
    expect(authResult!.fullName, 'Alex Vance');
    expect(authResult!.isNewUser, isFalse);
  });

  testWidgets('AuthScreen displays Early Access Full modal when capacity is reached',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    MockCapacityReachedAuthRepo.fakePrefs = prefs;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(MockCapacityReachedAuthRepo()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const AuthScreen(initialMode: AuthMode.options),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Continue with Google
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Verify Early Access Full modal appears
    expect(find.text('Early Access Full (150/150)'), findsOneWidget);
    expect(
      find.text(
        'FairShare has reached its 150-user private beta limit. '
        'New registrations are temporarily paused while we scale our infrastructure for public release.\n\n'
        'If you already have an account, please sign in below.',
      ),
      findsOneWidget,
    );
    expect(find.text('Already have an account? Sign In'), findsOneWidget);

    // Tap "Already have an account? Sign In" -> switches to emailSignIn mode
    await tester.tap(find.text('Already have an account? Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Email'), findsOneWidget);
  });
}

class MockCapacityReachedAuthRepo extends AuthRepository {
  static late SharedPreferences fakePrefs;

  MockCapacityReachedAuthRepo()
      : super(
          supabaseService: SupabaseService(),
          profileRepository: ProfileRepository(
            supabaseService: SupabaseService(),
            cacheService: LocalCacheService(fakePrefs),
          ),
          cacheService: LocalCacheService(fakePrefs),
        );

  @override
  Future<UserProfile?> signInWithGoogle() async {
    throw const UserCapacityReachedException();
  }

  @override
  Future<({UserProfile? user, bool requiresEmailConfirmation})> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    throw const UserCapacityReachedException();
  }
}
