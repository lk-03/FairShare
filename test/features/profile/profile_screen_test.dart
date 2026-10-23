import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/features/profile/presentation/screens/profile_screen.dart';
import 'package:fairshare/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:fairshare/features/profile/presentation/widgets/set_upi_sheet.dart';
import 'package:fairshare/features/profile/presentation/widgets/splitwise_import_sheet.dart';
import 'package:fairshare/features/profile/presentation/widgets/theme_settings_sheet.dart';

void main() {
  late SharedPreferences prefs;
  late LocalCacheService cacheService;

  final testUser = UserProfile(
    id: 'user_alex_123',
    email: 'alex.vance@fairshare.app',
    fullName: 'Alex Vance',
    nickname: 'Alex',
    username: 'alexv',
    vpaId: 'alex@okaxis',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
    await cacheService.saveCurrentUser(testUser);
  });

  Widget buildTestWidget({UserProfile? initialUser}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localCacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          return MaterialApp(
            theme: AppTheme.buildTheme(brightness: Brightness.dark),
            home: const ProfileScreen(),
          );
        },
      ),
    );
  }

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders ProfileScreen with hero card, options, and brand footer',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Header & User details
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Alex'), findsOneWidget); // Display name (nickname)
    expect(find.text('@alexv'), findsOneWidget); // Username
    expect(find.text('alex.vance@fairshare.app'), findsOneWidget); // Email
    expect(find.text('Verified UPI'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);

    // Options
    expect(find.text('Payment Methods (UPI)'), findsOneWidget);
    expect(find.text('alex@okaxis'), findsOneWidget);
    expect(find.text('Import CSV'), findsOneWidget);
    expect(find.text('Guide & Interactive Tour'), findsOneWidget);
    expect(find.text('Theme & Appearance'), findsOneWidget);

    // Logout & Footer
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('FairShare'), findsOneWidget);
    expect(find.textContaining('Check for updates'), findsOneWidget);
  });

  testWidgets('tapping Edit Profile opens EditProfileSheet and saves changes',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Edit Profile"
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileSheet), findsOneWidget);
    expect(find.text('NICKNAME (PRIMARY DISPLAY NAME)'), findsOneWidget);
    expect(find.text('USERNAME HANDLE (@TAG)'), findsOneWidget);
    expect(find.text('FULL LEGAL NAME'), findsOneWidget);

    // Edit nickname
    final nicknameFinder =
        find.byKey(const Key('edit_profile_nickname_field'));
    await tester.enterText(nicknameFinder, 'Alexander');
    await tester.pumpAndSettle();

    // Tap "Save Profile Changes"
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    // Verify sheet closed and updated nickname is shown on ProfileScreen
    expect(find.byType(EditProfileSheet), findsNothing);
    expect(find.text('Alexander'), findsOneWidget);
  });

  testWidgets('tapping Payment Methods (UPI) opens SetUpiSheet and updates VPA',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Payment Methods (UPI)"
    await tester.tap(find.text('Payment Methods (UPI)'));
    await tester.pumpAndSettle();

    expect(find.byType(SetUpiSheet), findsOneWidget);
    expect(find.text('Get Paid Easily'), findsOneWidget);
    expect(find.text('QUICK BANK HANDLES'), findsOneWidget);
    expect(find.text('Paste from Clipboard'), findsOneWidget);

    // Enter a new prefix
    final upiInputFinder = find.byKey(const Key('set_upi_input_field'));
    await tester.enterText(upiInputFinder, 'alex.vance');
    await tester.pumpAndSettle();

    // Tap popular handle chip '@okhdfcbank'
    await tester.tap(find.text('@okhdfcbank'));
    await tester.pumpAndSettle();

    // VPA should now be alex.vance@okhdfcbank and valid
    expect(find.text('alex.vance@okhdfcbank'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);

    // Save UPI ID
    await tester.tap(find.text('Save UPI ID'));
    await tester.pumpAndSettle();

    expect(find.byType(SetUpiSheet), findsNothing);
    expect(find.text('alex.vance@okhdfcbank'), findsOneWidget);
  });

  testWidgets('tapping Theme & Appearance opens ThemeSettingsSheet and toggles modes',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Theme & Appearance"
    await tester.tap(find.text('Theme & Appearance'));
    await tester.pumpAndSettle();

    expect(find.byType(ThemeSettingsSheet), findsOneWidget);
    expect(find.text('APPEARANCE MODE'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark Nordic'), findsOneWidget);
    expect(find.text('Dark AMOLED'), findsOneWidget);

    // Tap "Light"
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    // Close sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ThemeSettingsSheet), findsNothing);
  });

  testWidgets('tapping Import CSV opens CsvImportSheet',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Import CSV"
    await tester.tap(find.text('Import CSV'));
    await tester.pumpAndSettle();

    expect(find.byType(CsvImportSheet), findsOneWidget);
    expect(find.text('Browse & Import CSV File'), findsOneWidget);
    expect(find.text('Browse CSV File'), findsOneWidget);
    expect(find.text('How to export CSV from Splitwise'), findsOneWidget);

    // Close sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CsvImportSheet), findsNothing);
  });

  testWidgets('CsvImportSheet accepts CSV text and navigates to step 1 preview',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Import CSV"
    await tester.tap(find.text('Import CSV'));
    await tester.pumpAndSettle();

    // Open paste accordion
    await tester.tap(find.text('Or paste CSV text directly'));
    await tester.pumpAndSettle();

    const sample = '''Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james (removed)
2026-03-09,Fans,General,2800.00,INR,-700.00,2100.00,-700.00,-700.00
2026-03-10,Dmart,Household supplies,3800.00,INR,2850.00,-950.00,-950.00,-950.00
2026-03-11,keith j. paid Njj,Payment,110.00,INR,0.00,-110.00,0.00,110.00
2026-03-15,"Instamart(maggi,syrup,curd,banana)",Groceries,390.00,INR,-167.50,-167.50,335.00,0.00
2026-03-18,poori,Dining out,92.00,INR,46.00,-46.00,0.00,0.00
''';

    // Enter text in TextField
    await tester.enterText(find.byType(TextField), sample);
    await tester.pumpAndSettle();

    // Tap "Preview Pasted CSV"
    await tester.tap(find.text('Preview Pasted CSV'));
    await tester.pumpAndSettle();

    // Should now be on step 1 (Preview & Map)
    expect(find.text('NEW GROUP NAME'), findsOneWidget);
    expect(find.text('WHICH MEMBER IN THIS CSV ARE YOU?'), findsOneWidget);
    expect(find.text('Create Group & Import (5 Expenses)'), findsOneWidget);
    expect(find.text('LK'), findsWidgets);
    expect(find.text('Njj'), findsWidgets);
    expect(find.text('KATTU PUCHI'), findsWidgets);
    expect(find.text('keith james'), findsWidgets);
  });

  testWidgets('tapping Log Out shows confirmation dialog and cancels or logs out',
      (tester) async {
    setViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Log Out"
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.text('Are you sure you want to log out of FairShare?'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(cacheService.getCurrentUser(), isNotNull);

    // Tap "Log Out" again
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Confirm logout
    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(cacheService.getCurrentUser(), isNull);
  });
}
