import 'package:cipherspend/services/db_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:intl/intl.dart';
import '../services/sms_service.dart';
import '../services/prediction_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import 'manual_entry_screen.dart';
import 'visual_report_screen.dart';
import 'search_export_screen.dart';
import 'app_notifications_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// Helper to ask for SMS permissions
Future<void> requestSmsPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [Permission.sms].request();

  if (statuses[Permission.sms]!.isGranted) {
    print("✅ SMS Permission Granted");
  } else {
    print("❌ SMS Permission Denied");
  }
}

// [NEW] Added 'with WidgetsBindingObserver' to listen to app background/foreground state
class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
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
    "top_category_amount": 0.0,
  };

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  int _appNotificationCount = 0; // [NEW] Central Insights Hub Counter

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _listenToLiveSMS();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    ); // [NEW] Stop listening on close
    super.dispose();
  }

  // [NEW] Triggered every time the user comes back to the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(); // Sync any background messages
      _checkSmartPrompt(); // Ask Android if they just used a payment app
    }
  }

  // [NEW] The Insight Engine
  Future<void> _generateSmartInsights() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we already sent a daily insight today
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String lastInsightDate = prefs.getString('last_insight_date') ?? "";

    double spent = _forecast['spent'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    double projected = _forecast['projected'] ?? 0;
    String topCategory = _forecast['top_category'] ?? "None";
    double topAmount = _forecast['top_category_amount'] ?? 0;

    double progress = spent / budget;

    // 1. CRITICAL ALERT: Budget Exceeded (Will bypass the daily limit)
    if (progress >= 1.0) {
      bool exceededAlertSent =
          prefs.getBool('exceeded_alert_sent_$todayStr') ?? false;
      if (!exceededAlertSent) {
        await LocalNotificationService().showInsightNotification(
          id: 1,
          title: "🚨 Budget Breached!",
          body:
              "You've spent ₹${spent.toStringAsFixed(0)}, exceeding your ₹${budget.toStringAsFixed(0)} limit. Time to activate stealth mode!",
        );
        await DBService().saveAppNotification("🚨 Budget Breached!", "You've spent ₹${spent.toStringAsFixed(0)}, exceeding your ₹${budget.toStringAsFixed(0)} limit. Time to activate stealth mode!", DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool('exceeded_alert_sent_$todayStr', true);
        return;
      }
    }

    // If we already sent a normal insight today, stop here.
    if (lastInsightDate == todayStr) return;

    // 2. WARNING ALERT: 80% Threshold
    if (progress >= 0.8 && progress < 1.0) {
      await LocalNotificationService().showInsightNotification(
        id: 2,
        title: "⚠️ Approaching Red Zone",
        body:
            "You've used ${(progress * 100).toStringAsFixed(0)}% of your budget. Slow down on the spending!",
      );
      await DBService().saveAppNotification("⚠️ Approaching Red Zone", "You've used ${(progress * 100).toStringAsFixed(0)}% of your budget. Slow down on the spending!", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }

    // 3. PREDICTION ALERT: High Run Rate
    if (projected > budget && progress < 0.8) {
      await LocalNotificationService().showInsightNotification(
        id: 3,
        title: "🔮 AI Forecast Warning",
        body:
            "At your current daily rate, you will exceed your budget by ₹${(projected - budget).toStringAsFixed(0)} this month.",
      );
      await DBService().saveAppNotification("🔮 AI Forecast Warning", "At your current daily rate, you will exceed your budget by ₹${(projected - budget).toStringAsFixed(0)} this month.", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }

    // 4. BEHAVIORAL ALERT: Top Category Insight
    if (topCategory != "None" && (topAmount / spent) > 0.4) {
      // If one category is more than 40% of total spend
      await LocalNotificationService().showInsightNotification(
        id: 4,
        title: "📊 Top Spend: $topCategory",
        body:
            "You've dropped ₹${topAmount.toStringAsFixed(0)} on $topCategory. Is it a necessity or a luxury?",
      );
      await DBService().saveAppNotification("📊 Top Spend: $topCategory", "You've dropped ₹${topAmount.toStringAsFixed(0)} on $topCategory. Is it a necessity or a luxury?", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }
  }

  // [NEW] Logic to check App Usage Stats and prompt user
  Future<void> _checkSmartPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    bool isSmartPromptEnabled = prefs.getBool('smart_prompt_enabled') ?? false;
    if (!isSmartPromptEnabled) return;

    try {
      // 1. Check if user gave Android permission
      bool hasAccess = await platform.invokeMethod('hasUsageAccess');
      if (!hasAccess) return;

      // 2. Ask Android if a UPI app was used in the last 5 mins
      String? recentApp = await platform.invokeMethod('getRecentUpiApp');
      if (recentApp != null) {
        // 3. Check if our background listener already caught the transaction!
        bool alreadyLogged = await _smsService.hasRecentTransaction(5);

        if (!alreadyLogged) {
          // Anti-spam check: Only prompt once per 5 minutes
          int lastPrompt = prefs.getInt('last_smart_prompt') ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - lastPrompt >
              (5 * 60 * 1000)) {
            await prefs.setInt(
              'last_smart_prompt',
              DateTime.now().millisecondsSinceEpoch,
            );
            if (mounted) {
              _showSmartEntryDialog(recentApp);
            }
          }
        }
      }
    } catch (e) {
      print("Smart Prompt check failed: $e");
    }
  }

  // [NEW] The UI Dialog for the Smart Prompt
  void _showSmartEntryDialog(String appName) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController merchantController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Constants.colorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Constants.colorPrimary),
            const SizedBox(width: 10),
            const Text(
              "Smart Prompt",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "We noticed you recently used $appName. Did you make a payment?",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount (₹)",
                prefixIcon: const Icon(Icons.currency_rupee),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: merchantController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Merchant / Reason",
                prefixIcon: const Icon(Icons.store),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("NO", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.colorPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              double amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0) {
                final txn = TransactionModel(
                  hash: "SMART_${DateTime.now().millisecondsSinceEpoch}",
                  sender: "User",
                  body: "Smart Entry via $appName: ${merchantController.text}",
                  amount: amount,
                  category:
                      "Uncategorized", // Can be manually assigned later in Neural Override
                  type: "UPI",
                  merchant: merchantController.text.isNotEmpty
                      ? merchantController.text
                      : "Unknown",
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                );
                await _smsService.saveTransaction(txn);
                if (mounted) Navigator.pop(ctx);
                _loadData(); // Refresh Dashboard
              }
            },
            child: const Text("LOG EXPENSE"),
          ),
        ],
      ),
    );
  }

  // Open Android Notification Settings
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

    // Make sure Notification Service is fully initialized before generating insights
    await LocalNotificationService().init();

    // 1. DELTA SYNC: Catch up on missed messages (SMS + Notifications from Cache)
    await _smsService.silentBackgroundSync();

    // 2. Fetch Data
    final list = await _smsService.getTransactionsByMonth(_selectedMonth);
    final forecastData = await _predictionService.getForecastForMonth(
      _selectedMonth,
    );
    final appNotifCount = await DBService().getAppNotificationsCount();

    if (mounted) {
      if (mounted) {
        setState(() {
          _transactions = list;
          _forecast = forecastData;
          _appNotificationCount = appNotifCount;
          _isLoading = false;
        });

        // [NEW] Fire the insight engine after data is ready
        _generateSmartInsights();
      }
    }
  }

  void _listenToLiveSMS() {
    _smsService.liveTransactionStream.listen((txn) async {
      if (txn != null) {
        // 1. Check if a transaction with the same amount happened in the last 5 mins
        bool isDuplicate = await _smsService.existsSimilarTransaction(txn);

        if (isDuplicate) {
          // 2. Automatically default to dropping duplicates silently
          final prefs = await SharedPreferences.getInstance();

          // Changed default from 'ask' to 'auto_drop'
          String dedupeRule = prefs.getString('dedupe_rule') ?? 'auto_drop';

          if (dedupeRule == 'auto_drop') {
            print(
              "🛡️ SILENTLY DROPPED DUPLICATE: ₹${txn.amount} from ${txn.sender}",
            );
            // We do nothing. The duplicate is destroyed.
          } else {
            // Only ask if the user explicitly turned off auto-drop in settings
            if (mounted) {
              _showDuplicateDialog(txn);
            }
          }
        } else {
          // 3. NO DUPLICATE: Save automatically
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
              foregroundColor: Colors.black,
            ),
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
              Colors.redAccent,
            ),
            const Divider(color: Colors.white24),
            _buildDialogRow(
              "End of Month Est:",
              "₹${projected.toStringAsFixed(0)}",
              projected > budget ? Colors.red : Constants.colorPrimary,
            ),
            const SizedBox(height: 10),
            _buildDialogRow(
              "Next Month Est:",
              "₹${nextMonth.toStringAsFixed(0)}",
              Colors.blueAccent,
            ),
            const SizedBox(height: 15),
            Text(
              nextMonth > budget
                  ? "⚠ Projection: Based on your average daily spend, you may exceed your budget next month."
                  : "✅ Projection: You are on track to stay within budget next month.",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CLOSE",
              style: TextStyle(color: Constants.colorPrimary),
            ),
          ),
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
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.greenAccent;
    if (lowerCat.contains('travel')) return Colors.lightBlueAccent;
    if (lowerCat.contains('shopping')) return Colors.amberAccent;
    if (lowerCat.contains('bills')) return Colors.redAccent;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orangeAccent;
    if (lowerCat.contains('investment')) return Colors.purpleAccent;
    if (lowerCat.contains('transaction')) return Colors.indigoAccent;
    return Colors.grey;
  }

  IconData _getCategoryIcon(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Icons.fastfood_rounded;
    if (lowerCat.contains('travel')) return Icons.directions_car_rounded;
    if (lowerCat.contains('shopping')) return Icons.shopping_bag_rounded;
    if (lowerCat.contains('bills')) return Icons.receipt_rounded;
    if (lowerCat.contains('refund')) return Icons.currency_exchange_rounded;
    if (lowerCat.contains('cash')) return Icons.account_balance_wallet_rounded;
    if (lowerCat.contains('investment')) return Icons.trending_up_rounded;
    if (lowerCat.contains('transaction')) return Icons.swap_horiz_rounded;
    return Icons.payment_rounded;
  }

  Widget _buildPredictionCard() {
    double spent = _forecast['spent'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    String topCategory = _forecast['top_category'] ?? "None";

    bool isOverBudget = spent > budget;
    double progress = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    Color statusColor = isOverBudget ? Colors.redAccent : Constants.colorPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Stack(
        children: [
          // Ambient Neon Glow behind the card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          // Glassmorphic Card Surface
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Constants.colorSurface.withOpacity(0.8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.blur_on, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "FORECAST",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        isOverBudget ? "CRITICAL" : "ON TRACK",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.6, end: 1.0),
                  ],
                ),
                const SizedBox(height: 20),
                
                // --- MONEY ROW ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹", style: TextStyle(color: statusColor, fontSize: 24, fontWeight: FontWeight.w400)),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: spent),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("BUDGET", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text("₹${budget.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // --- PROGRESS BAR ---
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track
                        Container(
                          height: 8,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                        // Fill
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Container(
                              height: 8,
                              width: constraints.maxWidth * value,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 12),
                
                // --- SUBTEXT UNDER BAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}% Utilized",
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "₹${(budget - spent).abs().toStringAsFixed(0)} ${isOverBudget ? 'Over' : 'Left'}",
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // --- BOTTOM ACTION ROW ---
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pie_chart_outline, color: Constants.colorPrimary.withOpacity(0.8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Top Leak: $topCategory",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _showPredictionDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Constants.colorPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Constants.colorPrimary.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Constants.colorPrimary, size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            monthName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
        1,
      );
    });
    _loadData();
  }

  Widget _buildTransactionList() {
    return Expanded(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary),
            )
          : _transactions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (context, index) =>
                  _buildTransactionItem(_transactions[index])
                      .animate(delay: (index * 50).ms)
                      .fade(duration: 300.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security_update_warning_outlined,
            size: 80,
            color: Constants.colorPrimary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            "VAULT SECURE",
            style: TextStyle(
              color: Constants.colorPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "No unencrypted financial data\ndetected for this cycle.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // --- PERFECTED GLASS DECORATION TRANSACTION ITEM ---
  Widget _buildTransactionItem(TransactionModel txn) {
    final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: Key(txn.hash),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16), 
          ),
          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
        ),
        onDismissed: (direction) async {
          setState(() {
            _transactions.removeWhere((item) => item.hash == txn.hash);
          });

          final db = await DBService().database;
          await db.insert('ignored_hashes', {
            'hash': txn.hash,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.delete(
            Constants.tableTransactions,
            where: 'hash = ?',
            whereArgs: [txn.hash],
          );
          _loadData();
        },
        child: Container(
          // Using your glassDecoration, but wrapped precisely 
          decoration: Constants.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
          ),
          // CRITICAL FIX: This stops the Material tap ripple from bleeding out of the rounded corners
          clipBehavior: Clip.antiAlias, 
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Better breathing room
              onTap: () async {
                bool? updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(transaction: txn),
                  ),
                );
                if (updated == true) _loadData();
              },
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(txn.category).withOpacity(0.2),
                child: Icon(
                  _getCategoryIcon(txn.category),
                  color: _getCategoryColor(txn.category),
                  size: 20,
                ),
              ),
              title: Text(
                txn.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                "${txn.merchant} • ${DateFormat('dd MMM').format(date)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: Text(
                "₹${txn.amount.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Constants.colorPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          "CipherSpend", 
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0),
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
        backgroundColor: Constants.colorSurface,
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Builder(
              builder: (context) {
                Widget badge = Badge(
                  isLabelVisible: _appNotificationCount > 0,
                  label: Text(_appNotificationCount.toString()),
                  child: const Icon(Icons.notifications_active, color: Colors.amber),
                );
                return _appNotificationCount > 0 
                  ? badge.animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds)
                  : badge;
              }
            ),
            tooltip: "Insights Hub",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppNotificationsScreen()),
              );
              _loadData(); 
            },
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: "Search & Export",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchExportScreen()),
              );
            },
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.refresh), 
            onPressed: _loadData,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.bar_chart, color: Constants.colorPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisualReportScreen(
                    transactions: _transactions,
                    budget: _forecast['budget'] ?? 0.0,
                  ),
                ),
              );
            },
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8), 
        ],
      ),

      floatingActionButton: GestureDetector(
        onTap: () async {
          bool? didAdd = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ManualEntryScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
                  child: child,
                ));
              },
            ),
          );
          if (didAdd == true) {
            _loadData();
          }
        },
        child: Container(
          height: 60, width: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Constants.colorPrimary, Color(0xFF00FF88)]),
            boxShadow: [BoxShadow(color: Constants.colorPrimary.withOpacity(0.4), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 5))],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 30),
        ).animate().scale(curve: Curves.easeOutBack),
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