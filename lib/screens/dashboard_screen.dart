import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- ADDED: Required for MethodChannel
import 'package:shared_preferences/shared_preferences.dart'; // <-- Added here
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:intl/intl.dart';
import '../services/sms_service.dart';
import '../services/prediction_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import 'visual_report_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/db_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// Helper to ask for SMS permissions
Future<void> requestSmsPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.sms,
  ].request();

  if (statuses[Permission.sms]!.isGranted) {
    print("✅ SMS Permission Granted");
  } else {
    print("❌ SMS Permission Denied");
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsService _smsService = SmsService();
  final PredictionService _predictionService = PredictionService();

  // Native Bridge to talk to MainActivity.kt
  static const platform = MethodChannel('com.example.cipherspend/sms');

  List<TransactionModel> _transactions = [];

  Map<String, dynamic> _forecast = {
    "budget": 1.0,
    "spent": 0.0,
    "projected": 0.0,
    "next_month_projected": 0.0,
    "top_category": "None",
    "top_category_amount": 0.0
  };

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToLiveSMS();
  }

  // [NEW] Open Android Notification Settings
  Future<void> _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      print("Failed to open settings: $e");
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // 1. DELTA SYNC: Catch up on missed messages (SMS + Notifications from Cache)
    await _smsService.silentBackgroundSync();

    // 2. Fetch Data
    final list = await _smsService.getTransactionsByMonth(_selectedMonth);
    final forecastData =
        await _predictionService.getForecastForMonth(_selectedMonth);

    if (mounted) {
      setState(() {
        _transactions = list;
        _forecast = forecastData;
        _isLoading = false;
      });
    }
  }

  void _listenToLiveSMS() {
    _smsService.liveTransactionStream.listen((txn) async {
      if (txn != null) {
        bool isDuplicate = await _smsService.existsSimilarTransaction(txn);

        if (isDuplicate) {
          // Check user's global preference
          final prefs = await SharedPreferences.getInstance();
          String dedupeRule =
              prefs.getString('dedupe_rule') ?? 'ask'; // 'ask', 'auto_drop'

          if (dedupeRule == 'auto_drop') {
            print(
                "Silently dropped duplicate ₹${txn.amount} from ${txn.sender}");
            // Do nothing, drop it
          } else {
            // Ask the user case-by-case
            if (mounted) {
              _showDuplicateDialog(txn);
            }
          }
        } else {
          await _smsService.saveTransaction(txn);
          _refreshIfCurrentMonth(txn);
        }
      }
    });
  }

  void _refreshIfCurrentMonth(TransactionModel txn) {
    if (_selectedMonth.month == DateTime.now().month &&
        _selectedMonth.year == DateTime.now().year) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New Transaction: ₹${txn.amount}"),
            backgroundColor: Constants.colorPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDuplicateDialog(TransactionModel txn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Constants.colorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.copy, color: Colors.orange),
            SizedBox(width: 10),
            Text("Duplicate Detected", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          "We found a similar transaction of ₹${txn.amount} from ${txn.merchant}.\n\n"
          "This might be the same SMS/Notification detected again. Do you want to add it anyway?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("IGNORE", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorPrimary,
                foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(context);
              await _smsService.saveTransaction(txn);
              _refreshIfCurrentMonth(txn);
            },
            child: const Text("ADD ANYWAY"),
          ),
        ],
      ),
    );
  }

  void _showPredictionDialog() {
    double projected = _forecast['projected'] ?? 0;
    double nextMonth = _forecast['next_month_projected'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    String topCategory = _forecast['top_category'] ?? "None";
    double topAmount = _forecast['top_category_amount'] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Constants.colorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.insights, color: Constants.colorPrimary),
            SizedBox(width: 10),
            Text("Financial Forecast", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow(
                "Highest Spend:",
                "$topCategory (₹${topAmount.toStringAsFixed(0)})",
                Colors.redAccent),
            const Divider(color: Colors.white24),
            _buildDialogRow(
                "End of Month Est:",
                "₹${projected.toStringAsFixed(0)}",
                projected > budget ? Colors.red : Constants.colorPrimary),
            const SizedBox(height: 10),
            _buildDialogRow("Next Month Est:",
                "₹${nextMonth.toStringAsFixed(0)}", Colors.blueAccent),
            const SizedBox(height: 15),
            Text(
              nextMonth > budget
                  ? "⚠ Projection: Based on your average daily spend, you may exceed your budget next month."
                  : "✅ Projection: You are on track to stay within budget next month.",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE",
                style: TextStyle(color: Constants.colorPrimary)),
          )
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    double spent = _forecast['spent'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    String topCategory = _forecast['top_category'] ?? "None";

    bool isOverBudget = spent > budget;
    double progress = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    Color statusColor =
        isOverBudget ? Colors.redAccent : Constants.colorPrimary;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Constants.colorSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL SPENT",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text("₹${spent.toStringAsFixed(0)}",
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("MONTHLY BUDGET",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text("₹${budget.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black26,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverBudget
                    ? "⚠️ Budget Exceeded"
                    : "${(progress * 100).toStringAsFixed(0)}% Used",
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "Remaining: ₹${(budget - spent).toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: Colors.redAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Most Spent: $topCategory",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showPredictionDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Constants.colorPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Constants.colorPrimary.withOpacity(0.3))),
                  child: const Row(
                    children: [
                      Icon(Icons.insights,
                          color: Constants.colorPrimary, size: 14),
                      SizedBox(width: 6),
                      Text("View Projection",
                          style: TextStyle(
                              color: Constants.colorPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMonthSelector(String monthName) {
    return Container(
      color: Constants.colorSurface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _changeMonth(-1)),
          Text(monthName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => _changeMonth(1)),
        ],
      ),
    );
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
    _loadData();
  }

  Widget _buildTransactionList() {
    return Expanded(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary))
          : _transactions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) =>
                      _buildTransactionItem(_transactions[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security_update_warning_outlined,
              size: 80, color: Constants.colorPrimary.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text("VAULT SECURE",
              style: TextStyle(
                  color: Constants.colorPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          const SizedBox(height: 8),
          const Text("No unencrypted financial data\ndetected for this cycle.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel txn) {
    final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key(txn.hash),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
        ),
        onDismissed: (direction) async {
          setState(() {
            _transactions.removeWhere((item) => item.hash == txn.hash);
          });

          final db = await DBService().database;
          await db.insert('ignored_hashes', {'hash': txn.hash},
              conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.delete(Constants.tableTransactions,
              where: 'hash = ?', whereArgs: [txn.hash]);
          _loadData();
        },
        child: Card(
          color: Constants.colorSurface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            onTap: () async {
              bool? updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          TransactionDetailScreen(transaction: txn)));
              if (updated == true) _loadData();
            },
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(txn.category).withOpacity(0.2),
              child: Icon(_getCategoryIcon(txn.category),
                  color: _getCategoryColor(txn.category), size: 20),
            ),
            title: Text(txn.category,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
                "${txn.merchant} • ${DateFormat('dd MMM').format(date)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: Text("₹${txn.amount.toStringAsFixed(0)}",
                style: const TextStyle(
                    color: Constants.colorPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.green;
    if (lowerCat.contains('travel')) return Colors.blue;
    if (lowerCat.contains('shopping')) return Colors.amber;
    if (lowerCat.contains('bills')) return Colors.red;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orange;
    if (lowerCat.contains('investment')) return Colors.purpleAccent;
    if (lowerCat.contains('transaction')) return Colors.indigo;
    return Colors.grey;
  }

  IconData _getCategoryIcon(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Icons.fastfood;
    if (lowerCat.contains('travel')) return Icons.directions_car;
    if (lowerCat.contains('shopping')) return Icons.shopping_bag;
    if (lowerCat.contains('bills')) return Icons.receipt;
    if (lowerCat.contains('refund')) return Icons.currency_exchange;
    if (lowerCat.contains('cash')) return Icons.money;
    if (lowerCat.contains('investment')) return Icons.trending_up;
    if (lowerCat.contains('transaction')) return Icons.swap_horiz;
    return Icons.payment;
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("CipherSpend"),
        backgroundColor: Constants.colorSurface,
        actions: [
          // [NEW] Hybrid Engine Trigger
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.amber),
            tooltip: "Enable Notification Listener",
            onPressed: _openNotificationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Constants.colorPrimary),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => VisualReportScreen(
                            transactions: _transactions,
                            budget: _forecast['budget'] ?? 0.0,
                          )));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(monthName),
          _buildPredictionCard(),
          _buildTransactionList(),
        ],
      ),
    );
  }
}
