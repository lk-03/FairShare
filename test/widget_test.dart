import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FairShareApp smoke test renders brand and theme controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FairShareApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('THEME PALETTE'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });
}
