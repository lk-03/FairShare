import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/widgets/fairshare_desktop_sidebar.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FairShareDesktopSidebar displays nav items, download APK button, and styled dividers', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = LocalCacheService(prefs);
    await cache.saveCurrentUser(UserProfile(
      id: 'test_user',
      email: 'test@example.com',
      fullName: 'Test User',
      createdAt: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: FairShareDesktopSidebar(
              currentIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('Download APK'), findsOneWidget);
    expect(find.byIcon(Icons.android_rounded), findsOneWidget);

    // Dividers should use theme border color, not unstyled default
    final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
    expect(dividers.length, 2);
    for (final d in dividers) {
      expect(d.color, isNotNull);
    }
  });
}
