import '../services/db_service.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PredictionService {
  final DBService _db = DBService();

  Future<double> getMonthSpend(DateTime month) async {
    final db = await _db.database;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;

    final result = await db.rawQuery(
        "SELECT SUM(amount) as total FROM ${Constants.tableTransactions} WHERE timestamp >= ? AND timestamp < ?",
        [start, end]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, dynamic>> getForecastForMonth(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Get the target budget
    double budget = prefs.getDouble(Constants.prefMonthlyBudget) ?? 1.0;
    if (budget <= 0) budget = 1.0;

    // 2. Get actual spent
    double spent = await getMonthSpend(month);

    double projected = spent;
    double nextMonthProjected = budget;
    double averageDailySpend = 0.0;

    bool isCurrentMonth = month.month == now.month && month.year == now.year;

    if (isCurrentMonth) {
      int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      int daysPassed = now.day;
      int daysRemaining = daysInMonth - daysPassed;

      if (daysPassed > 0) {
        averageDailySpend = spent / daysPassed;

        // [THE FIX]: Budget-Aware Projection Algorithm
        if (daysPassed <= 7) {
          // Grace Period (Days 1-7): Assume user sticks to their daily budget for the rest of the month
          double dailyBudgetAllowance = budget / daysInMonth;
          projected = spent + (dailyBudgetAllowance * daysRemaining);
        } else {
          // After Day 7: Spending habits are established, switch to strict burn rate
          projected = spent + (averageDailySpend * daysRemaining);
        }

        // Next month projection uses the strict burn rate to warn them of consequences
        int nextMonthDays = DateTime(now.year, now.month + 2, 0).day;
        nextMonthProjected = averageDailySpend * nextMonthDays;
      }
    } else if (month.isBefore(DateTime(now.year, now.month, 1))) {
      // Past months
      int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      averageDailySpend = spent / daysInMonth;
      projected = spent;

      int nextMonthDays = DateTime(month.year, month.month + 2, 0).day;
      nextMonthProjected = averageDailySpend * nextMonthDays;
    }

    return {
      "budget": budget,
      "spent": spent,
      "projected": projected,
      "next_month_projected": nextMonthProjected,
      "ads": averageDailySpend,
      "progress": (spent / budget).clamp(0.0, 1.0)
    };
  }
}
