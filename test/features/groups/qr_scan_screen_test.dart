import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/groups/presentation/screens/qr_scan_screen.dart';

class _MockGroupsNotifier extends GroupsNotifier {
  final Group? groupToJoin;
  String? lastCodeAttempted;

  _MockGroupsNotifier({this.groupToJoin});

  @override
  AsyncValue<List<Group>> build() => const AsyncValue.data([]);

  @override
  Future<Group?> joinGroupByInviteCode(String inviteCode) async {
    lastCodeAttempted = inviteCode;
    return groupToJoin;
  }
}

void main() {
  final testGroup = Group(
    id: 'grp_12345',
    name: 'Apartment 404',
    inviteCode: 'APT404',
    createdBy: 'user_alex',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('QrScanScreen.extractInviteCode parser', () {
    test('extracts code from deep links', () {
      expect(QrScanScreen.extractInviteCode('fairshare://join/APT404'), 'APT404');
      expect(QrScanScreen.extractInviteCode('fairshare://join/blr-402_x'), 'BLR-402_X');
      expect(QrScanScreen.extractInviteCode('FAIRSHARE://JOIN/goa2026'), 'GOA2026');
    });

    test('extracts code from web links', () {
      expect(QrScanScreen.extractInviteCode('https://fairshare.app/join/APT404'), 'APT404');
      expect(QrScanScreen.extractInviteCode('http://staging.fairshare.internal/join/ROOM101'), 'ROOM101');
    });

    test('extracts raw alphanumeric invite codes', () {
      expect(QrScanScreen.extractInviteCode('APT404'), 'APT404');
      expect(QrScanScreen.extractInviteCode('  blr909  '), 'BLR909');
    });

    test('returns null for invalid inputs', () {
      expect(QrScanScreen.extractInviteCode(null), isNull);
      expect(QrScanScreen.extractInviteCode(''), isNull);
      expect(QrScanScreen.extractInviteCode('   '), isNull);
      expect(QrScanScreen.extractInviteCode('fairshare://other/path'), isNull);
    });
  });

  group('QrScanScreen widget rendering', () {
    testWidgets('renders header, viewfinder overlays, and manual buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsProvider.overrideWith(() => _MockGroupsNotifier(groupToJoin: testGroup)),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(brightness: Brightness.dark),
            home: const QrScanScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Scan Group QR'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_ios_rounded), findsOneWidget);
      expect(find.text('Align FairShare QR code within the frame'), findsOneWidget);
      expect(find.text('Enter Code Manually'), findsWidgets);
      expect(find.byIcon(Icons.science_outlined), findsWidgets);
    });

    testWidgets('Simulate QR Code dialog opens and processes valid code', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = _MockGroupsNotifier(groupToJoin: testGroup);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(brightness: Brightness.dark),
            home: const QrScanScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap simulate QR code button
      await tester.tap(find.byIcon(Icons.science_outlined).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Simulate QR Scan'), findsOneWidget);

      // Enter simulated deep link
      await tester.enterText(find.byType(TextField).last, 'fairshare://join/APT404');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Simulate Scan"
      await tester.tap(find.text('Simulate Scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(notifier.lastCodeAttempted, 'APT404');
    });
  });
}
