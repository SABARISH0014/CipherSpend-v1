import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/db_service.dart';
import '../services/sms_service.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../widgets/sync_overlay.dart'; 

import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import 'manual_entry_screen.dart';
import 'visual_report_screen.dart';
import 'search_export_screen.dart';
import 'app_notifications_screen.dart';
import 'profile_edit_screen.dart';

// --- Top Level Permission Request ---
Future<void> requestSmsPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [Permission.sms].request();
  if (statuses[Permission.sms]!.isGranted) {
    debugPrint("✅ SMS Permission Granted");
  } else {
    debugPrint("❌ SMS Permission Denied");
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final SmsService _smsService = SmsService();
  final PredictionService _predictionService = PredictionService();
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
  int _appNotificationCount = 0;
  bool _isFabPressed = false;

  // --- SYNC STATE VARIABLES ---
  bool _isSyncing = false;
  int _totalToSync = 0;
  int _currentSynced = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRunInitialSync(); 
    _listenToLiveSMS();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isSyncing) {
      _loadData();
      _checkSmartPrompt();
    }
  }

  Future<void> _checkAndRunInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSynced = prefs.getBool('has_initial_sync_completed') ?? false;

    if (!hasSynced) {
      setState(() => _isSyncing = true);

      await _smsService.syncHistory(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentSynced = current;
              _totalToSync = total;
            });
          }
        },
      );

      await prefs.setBool('has_initial_sync_completed', true);
      
      if (mounted) {
        setState(() => _isSyncing = false);
        _loadData(); 
      }
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await LocalNotificationService().init();
    await _smsService.silentBackgroundSync();
    
    final list = await _smsService.getTransactionsByMonth(_selectedMonth);
    final forecastData = await _predictionService.getForecastForMonth(_selectedMonth);
    final appNotifCount = await DBService().getAppNotificationsCount();
    
    if (mounted) {
      setState(() {
        _transactions = list;
        _forecast = forecastData;
        _appNotificationCount = appNotifCount;
        _isLoading = false;
      });
      _generateSmartInsights();
    }
  }

  Future<void> _generateSmartInsights() async {
    final prefs = await SharedPreferences.getInstance();
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String lastInsightDate = prefs.getString('last_insight_date') ?? "";

    double spent = _forecast['spent'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    double projected = _forecast['projected'] ?? 0;
    String topCategory = _forecast['top_category'] ?? "None";
    double topAmount = _forecast['top_category_amount'] ?? 0;

    double progress = spent / budget;

    if (progress >= 1.0) {
      bool exceededAlertSent = prefs.getBool('exceeded_alert_sent_$todayStr') ?? false;
      if (!exceededAlertSent) {
        await LocalNotificationService().showInsightNotification(
          id: 1,
          title: "🚨 Budget Breached!",
          body: "You've spent ₹${spent.toStringAsFixed(0)}, exceeding your ₹${budget.toStringAsFixed(0)} limit.",
        );
        await DBService().saveAppNotification("🚨 Budget Breached!", "You've spent ₹${spent.toStringAsFixed(0)}, exceeding your ₹${budget.toStringAsFixed(0)} limit.", DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool('exceeded_alert_sent_$todayStr', true);
        return;
      }
    }

    if (lastInsightDate == todayStr) return;

    if (progress >= 0.8 && progress < 1.0) {
      await LocalNotificationService().showInsightNotification(
        id: 2,
        title: "⚠️ Approaching Red Zone",
        body: "You've used ${(progress * 100).toStringAsFixed(0)}% of your budget.",
      );
      await DBService().saveAppNotification("⚠️ Approaching Red Zone", "You've used ${(progress * 100).toStringAsFixed(0)}% of your budget.", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }

    if (projected > budget && progress < 0.8) {
      await LocalNotificationService().showInsightNotification(
        id: 3,
        title: "🔮 AI Forecast Warning",
        body: "At your current daily rate, you will exceed your budget by ₹${(projected - budget).toStringAsFixed(0)} this month.",
      );
      await DBService().saveAppNotification("🔮 AI Forecast Warning", "At your current daily rate, you will exceed your budget by ₹${(projected - budget).toStringAsFixed(0)} this month.", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }

    if (topCategory != "None" && (topAmount / spent) > 0.4) {
      await LocalNotificationService().showInsightNotification(
        id: 4,
        title: "📊 Top Spend: $topCategory",
        body: "You've dropped ₹${topAmount.toStringAsFixed(0)} on $topCategory. Is it a necessity or a luxury?",
      );
      await DBService().saveAppNotification("📊 Top Spend: $topCategory", "You've dropped ₹${topAmount.toStringAsFixed(0)} on $topCategory. Is it a necessity or a luxury?", DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_insight_date', todayStr);
      return;
    }
  }

  Future<void> _checkSmartPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    bool isSmartPromptEnabled = prefs.getBool('smart_prompt_enabled') ?? false;
    if (!isSmartPromptEnabled) return;

    try {
      bool hasAccess = await platform.invokeMethod('hasUsageAccess');
      if (!hasAccess) return;

      String? recentApp = await platform.invokeMethod('getRecentUpiApp');
      if (recentApp != null) {
        bool alreadyLogged = await _smsService.hasRecentTransaction(5);
        if (!alreadyLogged) {
          int lastPrompt = prefs.getInt('last_smart_prompt') ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - lastPrompt > (5 * 60 * 1000)) {
            await prefs.setInt('last_smart_prompt', DateTime.now().millisecondsSinceEpoch);
            if (mounted) _showSmartEntryDialog(recentApp);
          }
        }
      }
    } catch (e) {
      debugPrint("Smart Prompt check failed: $e");
    }
  }

  void _showSmartEntryDialog(String appName) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController merchantController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: Constants.glassBlur,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: Constants.glassDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Constants.colorAccent),
                    const SizedBox(width: 10),
                    Text("Smart Prompt", style: Constants.headerStyle.copyWith(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "We noticed you recently used $appName. Did you make a payment?",
                  style: Constants.fontRegular,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "Amount (₹)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Constants.colorPrimary),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: merchantController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Merchant / Reason",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.store, color: Constants.colorPrimary),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32), // Added a bit more breathing room above the buttons
                
                // === CORRECTED BUTTON ROW ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("DISMISS", style: Constants.fontRegular.copyWith(color: Colors.white54)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // Perfect padding
                        backgroundColor: Constants.colorPrimary,
                        foregroundColor: Colors.black,
                        elevation: 6, // Slight glow effect
                        shadowColor: Constants.colorPrimary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        double amount = double.tryParse(amountController.text) ?? 0.0;
                        if (amount > 0) {
                          final txn = TransactionModel(
                            hash: "SMART_${DateTime.now().millisecondsSinceEpoch}",
                            sender: "User",
                            body: "Smart Entry via $appName: ${merchantController.text}",
                            amount: amount,
                            category: "Uncategorized",
                            type: "UPI",
                            merchant: merchantController.text.isNotEmpty ? merchantController.text : "Unknown",
                            timestamp: DateTime.now().millisecondsSinceEpoch,
                          );
                          await _smsService.saveTransaction(txn);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData(); 
                        }
                      },
                      child: const Text(
                        "LOG EXPENSE", 
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
        ),
      ),
    );
  }
  
  void _listenToLiveSMS() {
    _smsService.liveTransactionStream.listen((txn) async {
      if (txn != null) {
        bool isDuplicate = await _smsService.existsSimilarTransaction(txn);
        if (isDuplicate) {
          final prefs = await SharedPreferences.getInstance();
          String dedupeRule = prefs.getString('dedupe_rule') ?? 'auto_drop';

          if (dedupeRule == 'auto_drop') {
            debugPrint("🛡️ SILENTLY DROPPED DUPLICATE: ₹${txn.amount} from ${txn.sender}");
          } else {
            if (mounted) _showDuplicateDialog(txn);
          }
        } else {
          await _smsService.saveTransaction(txn);
          _refreshIfCurrentMonth(txn);
        }
      }
    });
  }

  void _refreshIfCurrentMonth(TransactionModel txn) {
    if (_selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New Transaction: ₹${txn.amount}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Constants.colorPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showDuplicateDialog(TransactionModel txn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: Constants.glassBlur,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: Constants.glassDecoration.copyWith(
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Text("Duplicate Detected", style: Constants.headerStyle.copyWith(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "We found a similar transaction of ₹${txn.amount} from ${txn.merchant}.\n\nThis might be the same SMS/Notification detected again. Do you want to add it anyway?",
                  style: Constants.fontRegular,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("IGNORE", style: Constants.fontRegular),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _smsService.saveTransaction(txn);
                        _refreshIfCurrentMonth(txn);
                      },
                      child: const Text("ADD ANYWAY", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, curve: Curves.easeOutCubic).fadeIn(),
        ),
      ),
    );
  }

  // --- FUTURISTIC POPUP FORECAST (UNTOUCHED) ---
  void _showPredictionDialog() {
    double projected = _forecast['projected'] ?? 0;
    double nextMonth = _forecast['next_month_projected'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    String topCategory = _forecast['top_category'] ?? "None";
    double topAmount = _forecast['top_category_amount'] ?? 0.0;
    bool exceedsNextMonth = nextMonth > budget;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: Constants.glassBlur,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: Constants.glassDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: Constants.colorAccent, size: 24),
                    const SizedBox(width: 12),
                    Text("Forecast", style: Constants.headerStyle.copyWith(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildForecastDataBox("Highest Spend Category", "$topCategory (₹${topAmount.toStringAsFixed(0)})", Constants.colorError),
                const SizedBox(height: 12),
                _buildForecastDataBox("End of Month Projection", "₹${projected.toStringAsFixed(0)}", projected > budget ? Constants.colorError : Constants.colorPrimary),
                const SizedBox(height: 12),
                _buildForecastDataBox("Next Month Estimate", "₹${nextMonth.toStringAsFixed(0)}", exceedsNextMonth ? Colors.orange : Constants.colorPrimary),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (exceedsNextMonth ? Colors.orange : Constants.colorPrimary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (exceedsNextMonth ? Colors.orange : Constants.colorPrimary).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(exceedsNextMonth ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: exceedsNextMonth ? Colors.orange : Constants.colorPrimary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          exceedsNextMonth
                              ? "Warning: Based on your daily average, you will exceed your budget next month."
                              : "On Track: Your current spending habits are sustainable.",
                          style: Constants.fontRegular.copyWith(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
  alignment: Alignment.centerRight,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      // ADDED: Padding and minimumSize to give the button a proper, clickable footprint
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      minimumSize: const Size(140, 44),
      
      backgroundColor: Constants.colorSurface,
      foregroundColor: Colors.white,
      
      // TWEAKED: Slightly thicker border and added a subtle shadow for depth
      side: const BorderSide(color: Constants.colorAccent, width: 1.5),
      elevation: 4,
      shadowColor: Constants.colorAccent.withValues(alpha: 0.3),
      
      // TWEAKED: Changed radius from 8 to 12 to match the dialog's other elements
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () => Navigator.pop(context),
    child: const Text(
      "CLOSE TERMINAL", 
      style: TextStyle(
        letterSpacing: 1.5, // Increased letter spacing for a digital feel
        fontSize: 12, 
        fontWeight: FontWeight.bold
      ),
    ),
  ),
),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
        ),
      ),
    );
  }

  Widget _buildForecastDataBox(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label, style: Constants.fontRegular.copyWith(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value, 
              style: Constants.headerStyle.copyWith(fontSize: 13, color: accentColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // --- NEON AI FORECAST CARD (UNTOUCHED) ---
  Widget _buildPredictionCard() {
    double spent = _forecast['spent'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    String topCategory = _forecast['top_category'] ?? "None";

    bool isOverBudget = spent > budget;
    double progress = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    Color statusColor = isOverBudget ? Colors.redAccent : Constants.colorPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12), // Reduced bottom margin
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Constants.colorSurface.withValues(alpha: 0.8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.blur_on, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "FORECAST",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isOverBudget ? "CRITICAL" : "ON TRACK",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.6, end: 1.0),
                  ],
                ),
                const SizedBox(height: 20),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹", style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.w400)),
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
                            fontSize: 36, 
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
                        Text("BUDGET", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text("₹${budget.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 6, 
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Container(
                              height: 6, 
                              width: constraints.maxWidth * value,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.8),
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
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}% Utilized",
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "₹${(budget - spent).abs().toStringAsFixed(0)} ${isOverBudget ? 'Over' : 'Left'}",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pie_chart_outline, color: Constants.colorPrimary.withValues(alpha: 0.8), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Top Leak: $topCategory",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
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
                          color: Constants.colorPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Constants.colorPrimary, size: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, curve: Curves.easeOutBack);
  }

  // --- SLEEK MONTH SELECTOR ---
  Widget _buildMonthSelector(String monthName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24),
            onPressed: () => _changeMonth(-1)
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1))
            ),
            child: Text(monthName, style: Constants.headerStyle.copyWith(fontSize: 14, letterSpacing: 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
            onPressed: () => _changeMonth(1)
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
    _loadData();
  }

  // --- NEW TRANSACTION LIST WITH HEADERS AND 3D FLIP ENTRY ---
  Widget _buildTransactionList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, size: 14, color: Constants.colorAccent),
                const SizedBox(width: 8),
                Text(
                  "DECRYPTED LEDGER",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Constants.colorPrimary))
                : _transactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100, top: 4),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(_transactions[index])
                          .animate()
                          .fade(duration: 500.ms, delay: (50 * index).ms)
                          .slideY(begin: 0.2, curve: Curves.easeOutCubic)
                          .flipV(begin: -0.1, end: 0, curve: Curves.easeOutCubic); // Added subtle 3D flip
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- NEW SCANNING RADAR EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.2), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 2.seconds).fade(end: 0),
              Icon(Icons.radar_rounded, size: 50, color: Constants.colorPrimary.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Text("LEDGER EMPTY", style: Constants.headerStyle.copyWith(color: Constants.colorPrimary.withValues(alpha: 0.8), letterSpacing: 4, fontSize: 14)),
          const SizedBox(height: 8),
          Text("No offline financial data\nintercepted for this cycle.", textAlign: TextAlign.center, style: Constants.subHeaderStyle.copyWith(fontSize: 11)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(curve: Curves.easeOutBack);
  }

  // --- UPGRADED CYBER-NODE TRANSACTION CARDS ---
  Widget _buildTransactionItem(TransactionModel txn) {
    final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);
    final catColor = _getCategoryColor(txn.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Adds a very subtle ambient glow behind the entire card based on its category
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.03),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(txn.hash),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Constants.colorError.withValues(alpha: 0.5), width: 1.5),
            // Upgraded purge background with a tech-warning gradient
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Constants.colorError.withValues(alpha: 0.05),
                Constants.colorError.withValues(alpha: 0.25),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("PURGE", 
                style: TextStyle(
                  color: Constants.colorError, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 3, 
                  fontSize: 12,
                  shadows: [Shadow(color: Constants.colorError.withValues(alpha: 0.5), blurRadius: 4)]
                )
              ),
              const SizedBox(width: 12),
              const Icon(Icons.delete_sweep_rounded, color: Constants.colorError, size: 24),
            ],
          ),
        ),
        onDismissed: (direction) async {
          setState(() => _transactions.removeWhere((item) => item.hash == txn.hash));
          final db = await DBService().database;
          await db.insert('ignored_hashes', {'hash': txn.hash}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.delete(Constants.tableTransactions, where: 'hash = ?', whereArgs: [txn.hash]);
          _loadData();
        },
        child: InkWell(
          onTap: () async {
            bool? updated = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: txn)),
            );
            if (updated == true) _loadData();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Constants.colorSurface.withValues(alpha: 0.6), // Glassier background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1), 
              // Soft gradient fading from the category color into the dark surface
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  catColor.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // UPGRADED: True glowing neon LED strip
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: catColor,
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Category Icon with subtle border
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: catColor.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Icon(_getCategoryIcon(txn.category), color: catColor, size: 18),
                  ),
                  const SizedBox(width: 16),
                  
                  // Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16), // Slightly more breathing room
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            txn.merchant, 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w700, 
                              fontSize: 15, 
                              letterSpacing: 0.5
                            )
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  txn.category.toUpperCase(), 
                                  style: TextStyle(color: catColor.withValues(alpha: 0.9), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.3), size: 10),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM, HH:mm').format(date), 
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Courier') 
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Amount
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(
                      "₹${txn.amount.toStringAsFixed(0)}", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 18, // Slightly larger
                        fontWeight: FontWeight.w800, 
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))
                        ]
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    if (lowerCat.contains('investment')) return Constants.colorAccent;
    if (lowerCat.contains('transaction')) return Colors.indigoAccent;
    return Colors.grey;
  }

  IconData _getCategoryIcon(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Icons.fastfood_rounded;
    if (lowerCat.contains('travel')) return Icons.directions_car_rounded;
    if (lowerCat.contains('shopping')) return Icons.shopping_bag_rounded;
    if (lowerCat.contains('bills')) return Icons.receipt_long_rounded;
    if (lowerCat.contains('refund')) return Icons.currency_exchange_rounded;
    if (lowerCat.contains('cash')) return Icons.account_balance_wallet_rounded;
    if (lowerCat.contains('investment')) return Icons.trending_up_rounded;
    if (lowerCat.contains('transaction')) return Icons.swap_horiz_rounded;
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent, 
        
        // ADDED: Forces the title to perfectly align to the left
        centerTitle: false, 
        
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0), // Tweak this number to get the exact spacing you want
          child: Text(
            "CIPHER SPEND", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _appNotificationCount > 0,
              label: Text(_appNotificationCount.toString(), style: const TextStyle(fontSize: 10)),
              backgroundColor: Constants.colorError,
              child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 22),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AppNotificationsScreen()));
              _loadData(); 
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            tooltip: "Search & Export",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchExportScreen())),
          ),
          
          // --- SLEEK POPUP MENU ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
            color: Constants.colorSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            offset: const Offset(0, 50),
            onSelected: (value) async {
              if (value == 'refresh') {
                _loadData();
              } else if (value == 'report') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => VisualReportScreen(transactions: _transactions, budget: _forecast['budget'] ?? 0.0)));
              } else if (value == 'profile') {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                _loadData(); 
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(children: [const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20), const SizedBox(width: 12), Text("Refresh Sync", style: Constants.fontRegular.copyWith(fontSize: 14))]),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(children: [const Icon(Icons.bar_chart_rounded, color: Constants.colorAccent, size: 20), const SizedBox(width: 12), Text("Visual Report", style: Constants.fontRegular.copyWith(fontSize: 14))]),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(children: [const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 20), const SizedBox(width: 12), Text("Profile & Budget", style: Constants.fontRegular.copyWith(fontSize: 14))]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(children: [const Icon(Icons.settings_outlined, color: Colors.white70, size: 20), const SizedBox(width: 12), Text("Settings", style: Constants.fontRegular.copyWith(fontSize: 14))]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      
// [FIXED] Hide the FAB completely while the initial sync is running
      floatingActionButton: _isSyncing 
        ? null 
        : GestureDetector(
            onTapDown: (_) => setState(() => _isFabPressed = true),
            onTapUp: (_) async {
              setState(() => _isFabPressed = false);
              bool? didAdd = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()));
              if (didAdd == true) _loadData();
            },
            onTapCancel: () => setState(() => _isFabPressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: Matrix4.diagonal3Values(_isFabPressed ? 0.9 : 1.0, _isFabPressed ? 0.9 : 1.0, 1.0),
              alignment: Alignment.center,
              width: 60, 
              height: 60, 
              decoration: BoxDecoration(
                color: Constants.colorPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Constants.colorPrimary.withValues(alpha: _isFabPressed ? 0.3 : 0.6),
                    blurRadius: _isFabPressed ? 10 : 20,
                    spreadRadius: _isFabPressed ? 2 : 5,
                  )
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.black, size: 32), 
            ),
          ).animate().scale(delay: 800.ms, duration: 500.ms, curve: Curves.easeOutBack),
      
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildMonthSelector(monthName),
                _buildPredictionCard(),
                _buildTransactionList(),
              ],
            ),
          ),
          
          if (_isSyncing)
            SyncOverlay(
              total: _totalToSync,
              current: _currentSynced,
              status: "Importing Financial History...",
            ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}