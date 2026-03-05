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

  // [NEW] Helper to find the category with the highest spend
  Future<Map<String, dynamic>> getTopCategory(DateTime month) async {
    final db = await _db.database;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM ${Constants.tableTransactions} 
      WHERE timestamp >= ? AND timestamp < ? 
      GROUP BY category 
      ORDER BY total DESC 
      LIMIT 1
    ''', [start, end]);

    if (result.isNotEmpty) {
      return {
        'category': result.first['category'] as String,
        'amount': (result.first['total'] as num).toDouble()
      };
    }
    return {'category': 'None', 'amount': 0.0};
  }

  Future<Map<String, dynamic>> getForecastForMonth(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Get the target budget
    double budget = prefs.getDouble(Constants.prefMonthlyBudget) ?? 1.0;
    if (budget <= 0) budget = 1.0;

    // 2. Get actual spent
    double spent = await getMonthSpend(month);

    // 3. Get Top Category (Highest Spend)
    Map<String, dynamic> topCat = await getTopCategory(month);

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

        if (daysPassed <= 7) {
          double dailyBudgetAllowance = budget / daysInMonth;
          projected = spent + (dailyBudgetAllowance * daysRemaining);
        } else {
          projected = spent + (averageDailySpend * daysRemaining);
        }

        int nextMonthDays = DateTime(now.year, now.month + 2, 0).day;
        nextMonthProjected = averageDailySpend * nextMonthDays;
      }
    } else if (month.isBefore(DateTime(now.year, now.month, 1))) {
      int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      averageDailySpend = spent / daysInMonth;
      projected = spent;
      nextMonthProjected = budget; // Reset for past months
    }

    return {
      "budget": budget,
      "spent": spent,
      "projected": projected,
      "next_month_projected": nextMonthProjected,
      "ads": averageDailySpend,
      "progress": (spent / budget).clamp(0.0, 1.0),
      "top_category": topCat['category'], // [NEW]
      "top_category_amount": topCat['amount'] // [NEW]
    };
  }
}
