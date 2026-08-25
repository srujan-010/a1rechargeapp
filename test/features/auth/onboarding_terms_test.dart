import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a1_recharge/features/auth/screens/registration_screen.dart';

void main() {
  testWidgets('Onboarding Step 4 — Terms Card & Legal Links Verification', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegistrationScreen(
            mobile: '9440751149',
            tempSessionToken: 'test_token_123',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Step 0 loaded
    expect(find.text('Select Account Type'), findsOneWidget);

    // Tap Retailer Account
    await tester.tap(find.text('Retailer Account'));
    await tester.pumpAndSettle();

    // Tap Continue to Step 1
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Fill Step 1 required fields
    final nameField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Owner / Full Name *');
    final shopField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Business / Shop Name *');
    final addressField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Shop Address / Location *');

    await tester.enterText(nameField, 'Test Owner');
    await tester.enterText(shopField, 'Test Shop');
    await tester.enterText(addressField, '123 Main Street, Hyderabad');
    await tester.pumpAndSettle();

    // Tap Continue to Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Tap Continue to Step 3 (Step 4 of 4 Terms & Agreement)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify Step 4 loaded
    expect(find.text('Terms & Agreement'), findsOneWidget);
    expect(find.text('Retailer Service Agreement & Terms'), findsOneWidget);
    expect(find.text('View Terms & Conditions'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsNWidgets(2)); // Card view + inline link
    expect(find.text('Privacy Policy'), findsOneWidget);

    // Verify Complete Onboarding button is initially disabled because checkbox is unchecked
    final completeButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(completeButton.onPressed, isNull);

    // Tap Checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Verify Complete Onboarding button is now ENABLED
    final enabledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(enabledButton.onPressed, isNotNull);
  });
}
