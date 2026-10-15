import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/app_update_info.dart';
import 'package:fairshare/core/widgets/update_available_dialog.dart';

void main() {
  testWidgets('UpdateAvailableDialog renders version, release notes, and actions',
      (tester) async {
    const updateInfo = AppUpdateInfo(
      tagName: 'v1.1.0',
      version: '1.1.0',
      releaseNotes: '• Major performance overhaul\n• Added receipt splitting',
      apkDownloadUrl: 'https://example.com/app.apk',
      hasUpdate: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateAvailableDialog(updateInfo: updateInfo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.textContaining('v1.1.0'), findsOneWidget);
    expect(find.textContaining('Major performance overhaul'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
  });
}
