import '../services/db_service.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PredictionService {
  final DBService _db = DBService();

  /// Get total spend for a specific CALENDAR month
  Future<double> getMonthSpend(DateTime month) async {
    final db = await _db.database;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    // Calculation for end of month handles year rollover automatically
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;

    final result = await db.rawQuery(
        "SELECT SUM(amount) as total FROM ${Constants.tableTransactions} WHERE timestamp >= ? AND timestamp < ?",
        [start, end]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Generate Forecast Data with Smart Buffer
  Future<Map<String, double>> getForecastForMonth(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Default budget to 1.0 to prevent division by zero errors in the UI progress bar
    double budget = prefs.getDouble(Constants.prefMonthlyBudget) ?? 1.0;
    if (budget == 0) budget = 1.0;

    double spent = await getMonthSpend(month);

    double projected = spent;
    double averageDailySpend = 0.0;

    bool isCurrentMonth = month.month == now.month && month.year == now.year;

    if (isCurrentMonth) {
      int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      // [FIXED] Align daysPassed strictly with the Calendar Month to match the SQL query
      int daysPassed = now.day;
      int daysRemaining = daysInMonth - daysPassed;

      if (daysPassed > 0) {
        averageDailySpend = spent / daysPassed;

        // Week 3 "Intelligence": Projected = Current + (Burn Rate * Days Left * 1.1 Buffer)
        // This accounts for the usual end-of-month spending spike.
        projected = spent + (averageDailySpend * daysRemaining * 1.1);
      }
    } else if (month.isBefore(DateTime(now.year, now.month, 1))) {
      // Past data is final. No projection needed.
      projected = spent;
      int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      averageDailySpend = spent / daysInMonth;
    }

    return {
      "budget": budget,
      "spent": spent,
      "projected": projected,
      "ads": averageDailySpend, // Average Daily Spend
      "progress": (spent / budget).clamp(0.0, 1.0)
    };
  }
}
