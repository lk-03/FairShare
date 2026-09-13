import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/widgets/category_icon.dart';

void main() {
  testWidgets('CategoryIcon renders mapped category icon and styling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryIcon(
            category: 'trip',
            size: 48,
            variant: CategoryIconVariant.solid,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
  });

  testWidgets('CategoryIcon renders custom mapped icon name correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryIcon(
            category: 'custom',
            customIcon: 'cart',
            size: 48,
            variant: CategoryIconVariant.solid,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
  });

  testWidgets('CategoryIcon renders light variant badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryIcon(
            category: 'house',
            size: 40,
            variant: CategoryIconVariant.light,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });
}
