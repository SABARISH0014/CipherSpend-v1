import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sms_service.dart';
import '../services/prediction_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../widgets/sync_overlay.dart'; // Correctly import the overlay
import 'transaction_detail_screen.dart';
import 'settings_screen.dart';
import 'visual_report_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

Future<void> requestSmsPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.sms,
  ].request();

  if (statuses[Permission.sms]!.isGranted) {
    print("✅ SMS Permission Granted");
  } else {
    print("❌ SMS Permission Denied");
    // Show a dialog explaining why you need it for CipherSpend to work
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsService _smsService = SmsService();
  final PredictionService _predictionService = PredictionService();

  List<TransactionModel> _transactions = [];
  Map<String, double> _forecast = {
    "budget": 1.0,
    "spent": 0.0,
    "projected": 0.0
  };

  // --- Week 3 Sync States ---
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  bool _isSyncing = false;
  int _totalToSync = 0;
  int _currentSynced = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToLiveSMS();
  }

  /// Integrated Load & Sync with Progress Tracking
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isSyncing = true; // Show Overlay
    });

    // 1. Sync Historical Data (Passes progress callback to SmsService)
    await _smsService.syncHistory(onProgress: (current, total) {
      if (mounted) {
        setState(() {
          _currentSynced = current;
          _totalToSync = total;
        });
      }
    });

    // 2. Fetch Data for SELECTED Month
    final list = await _smsService.getTransactionsByMonth(_selectedMonth);

    // 3. Calculate Intelligence Forecast
    final forecastData =
        await _predictionService.getForecastForMonth(_selectedMonth);

    if (mounted) {
      setState(() {
        _transactions = list;
        _forecast = forecastData;
        _isSyncing = false; // Hide Overlay
        _isLoading = false;
      });
    }
  }

  void _listenToLiveSMS() {
    _smsService.liveTransactionStream.listen((txn) async {
      if (txn != null) {
        await _smsService.saveTransaction(txn);
        if (_selectedMonth.month == DateTime.now().month &&
            _selectedMonth.year == DateTime.now().year) {
          _loadData(); // Refresh UI for new transaction
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
    });
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
    _loadData();
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Force AI Sync",
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Constants.colorPrimary),
            tooltip: "View Flow Chart",
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
      body: Stack(
        // Stack allows the Overlay to float over the UI
        children: [
          // 1. MAIN UI LAYER
          Column(
            children: [
              _buildMonthSelector(monthName),
              _buildPredictionCard(),
              _buildTransactionList(),
            ],
          ),

          // 2. OVERLAY LAYER (Only visible during sync)
          if (_isSyncing && _totalToSync > 0)
            SyncOverlay(total: _totalToSync, current: _currentSynced),
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

  Widget _buildPredictionCard() {
    double spent = _forecast['spent'] ?? 0;
    double projected = _forecast['projected'] ?? 0;
    double budget = _forecast['budget'] ?? 1;
    bool isDanger = projected > budget;
    double progress = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Constants.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: isDanger
            ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn(
                  "SPENT", "₹${spent.toStringAsFixed(0)}", Colors.white),
              _buildStatColumn(
                (_selectedMonth.month == DateTime.now().month)
                    ? "PROJECTED"
                    : "BUDGET",
                (_selectedMonth.month == DateTime.now().month)
                    ? "₹${projected.toStringAsFixed(0)}"
                    : "₹${budget.toStringAsFixed(0)}",
                isDanger ? Colors.redAccent : Constants.colorPrimary,
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
              color: isDanger ? Colors.redAccent : Constants.colorPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment:
          label == "SPENT" ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Expanded(
      child: _isLoading && !_isSyncing
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary))
          : _transactions.isEmpty
              ? const Center(
                  child:
                      Text("No Transactions", style: Constants.subHeaderStyle))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) =>
                      _buildTransactionItem(_transactions[index]),
                ),
    );
  }

  Widget _buildTransactionItem(TransactionModel txn) {
    final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);
    return Card(
      color: Constants.colorSurface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          bool? updated = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transaction: txn)));
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
        subtitle: Text("${txn.merchant} • ${DateFormat('dd MMM').format(date)}",
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text("₹${txn.amount.toStringAsFixed(0)}",
            style: const TextStyle(
                color: Constants.colorPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains('Food')) return Colors.green;
    if (cat.contains('Travel')) return Colors.blue;
    if (cat.contains('Shopping')) return Colors.amber;
    if (cat.contains('Bills')) return Colors.red;
    return Colors.grey;
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('Food')) return Icons.fastfood;
    if (cat.contains('Travel')) return Icons.directions_car;
    if (cat.contains('Shopping')) return Icons.shopping_bag;
    if (cat.contains('Bills')) return Icons.receipt;
    return Icons.payment;
  }
}
