import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cipherspend/models/transaction_model.dart';
import 'package:cipherspend/screens/transaction_detail_screen.dart';
import 'package:cipherspend/screens/interactive_training_screen.dart';

void main() {
  testWidgets('Neural Override screen successfully navigates to Interactive Training Screen', (WidgetTester tester) async {
    // 1. Create a Mock Transaction
    final mockTransaction = TransactionModel(
      hash: 'TESTHASH123',
      sender: 'V-HDFCBK',
      body: 'Paid Rs. 500.00 to AMAZON via UPI',
      amount: 500.00,
      category: 'Shopping',
      type: 'UPI',
      merchant: 'AMAZON',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // 2. Pump the Widget inside a MaterialApp
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionDetailScreen(transaction: mockTransaction),
      ),
    );

    // Let the Future load Categories in initstate
    await tester.pumpAndSettle();

    // 3. Verify Neural Override screen is displayed
    expect(find.text('Neural Override'), findsOneWidget);
    expect(find.text('EXECUTE OVERRIDE'), findsOneWidget);
    expect(find.text('TRAIN REGEX PARSER'), findsOneWidget);

    // The TweenAnimationBuilder might leave the cursor on during pumpAndSettle or off.
    // Testing the exact string with or without the block cursor can be flaky in widget tests.
    // Instead of expecting 'Paid Rs. 500.00 to AMAZON via UPI█', we can just check if
    // any text widget contains the body.
    expect(find.textContaining('Paid Rs. 500.00 to AMAZON via UPI'), findsOneWidget);

    // 4. Tap the 'TRAIN REGEX PARSER' button
    await tester.ensureVisible(find.text('TRAIN REGEX PARSER'));
    await tester.tap(find.text('TRAIN REGEX PARSER'));
    
    // Wait for the navigation transition to complete
    await tester.pumpAndSettle();

    // 5. Verify we have reached the InteractiveTrainingScreen
    expect(find.byType(InteractiveTrainingScreen), findsOneWidget);
    
    // 6. Verify the specific UI elements of the InteractiveTrainingScreen
    expect(find.text('Train Parser'), findsOneWidget);
    
    // Check if the words are split into chips.
    // The SMS body: 'Paid Rs. 500.00 to AMAZON via UPI' has 7 words
    // We expect at least one of these words in an ActionChip.
    expect(find.text('500.00'), findsOneWidget);
    expect(find.text('AMAZON'), findsOneWidget);
  });
}
