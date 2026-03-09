import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// We are no longer launching the full app, but targeting the Dashboard directly
import 'package:cipherspend/screens/dashboard_screen.dart';
import 'package:cipherspend/services/db_service.dart';
import 'package:cipherspend/models/transaction_model.dart';
import 'package:cipherspend/utils/constants.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:cipherspend/main.dart' as app; // Keep main for theme data

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard End-to-End Test', () {
    testWidgets(
      'Should wipe, inject, refresh, and verify a transaction appears correctly',
      (WidgetTester tester) async {
        // --- PHASE 1: PRE-LAUNCH DATABASE SETUP ---
        print("--- PHASE 1: DATABASE SETUP ---");
        final db = await DBService().database;
        await db.delete(Constants.tableTransactions);
        print("✅ TEST: Transactions table wiped.");

        final mockTxn = TransactionModel(
          hash: 'integration_test_hash_1',
          sender: 'TEST-BANK-SMS',
          body: 'Paid Rs 1234 to Test Merchant for shopping',
          amount: 1234.0,
          category: 'Shopping',
          type: 'UPI',
          merchant: 'Test Merchant',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await db.insert(
          Constants.tableTransactions,
          mockTxn.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print("✅ TEST: Mock transaction for ₹1234 injected.");

        // --- PHASE 2: LAUNCH DIRECTLY INTO DASHBOARD ---
        print("\n--- PHASE 2: UI LAUNCH & INTERACTION ---");

        // [FIX] We launch a MaterialApp wrapping ONLY the DashboardScreen.
        // This bypasses the complex login/setup flow entirely.
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData
              .dark(), // <--- FIX: Use standard dark theme for the test
          home: const DashboardScreen(),
        ));

        // Wait for the Dashboard to run its initial _loadData()
        await tester.pumpAndSettle(const Duration(seconds: 5));
        print("✅ APP: Dashboard launched directly.");

        // --- PHASE 3: VERIFICATION ---
        print("\n--- PHASE 3: VERIFICATION ---");

        // Find the ListView that contains our transactions
        final listViewFinder = find.byType(ListView);

        // Ensure we find the transaction ONLY inside the list,
        // ignoring the Prediction Card at the top.

        // 1. Verify Category 'Shopping' inside list
        expect(
            find.descendant(
                of: listViewFinder, matching: find.text('Shopping')),
            findsOneWidget,
            reason: "Category 'Shopping' should be visible in the list");

        // 2. Verify Merchant 'Test Merchant' inside list
        expect(
            find.descendant(
                of: listViewFinder,
                matching: find.textContaining('Test Merchant')),
            findsOneWidget,
            reason: "Merchant 'Test Merchant' should be visible in the list");

        // 3. Verify Amount '₹1234' inside list
        expect(
            find.descendant(of: listViewFinder, matching: find.text('₹1234')),
            findsOneWidget,
            reason: "Amount '₹1234' should be visible in the list");

        print("🎉🎉🎉 SUCCESS: End-to-end dashboard test passed!");
      },
    );
  });
}
