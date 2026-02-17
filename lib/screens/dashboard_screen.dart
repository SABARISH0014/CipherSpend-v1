import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsService _smsService = SmsService();
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToLiveSMS();
  }

  // Initial Load: Sync History & Fetch DB
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Sync History (Background)
    int newCount = await _smsService.syncHistory();
    if (newCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Synced $newCount new transactions")));
    }

    // 2. Fetch from DB
    await _refreshList();
  }

  Future<void> _refreshList() async {
    final list = await _smsService.getTransactions();
    setState(() {
      _transactions = list;
      _isLoading = false;
    });
  }

  // Live Listener
  void _listenToLiveSMS() {
    _smsService.liveTransactionStream.listen((txn) async {
      if (txn != null) {
        await _smsService.saveTransaction(txn);
        await _refreshList(); // Update UI instantly
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("New Spend: ₹${txn.amount} detected!")));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("CipherSpend Dashboard"),
        backgroundColor: Constants.colorSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary))
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 60, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      const Text("No Transactions Found",
                          style: Constants.subHeaderStyle),
                      const Text("Wait for SMS or tap Refresh to scan history.",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final txn = _transactions[index];
                    final date =
                        DateTime.fromMillisecondsSinceEpoch(txn.timestamp);

                    return Card(
                      color: Constants.colorSurface,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(txn.category),
                          child: Icon(_getCategoryIcon(txn.category),
                              color: Colors.white, size: 20),
                        ),

                        // --- OVERFLOW FIX STARTS HERE ---
                        title: Row(
                          children: [
                            // 1. Category Name (Takes remaining space)
                            Expanded(
                              child: Text(
                                txn.category,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow
                                    .ellipsis, // Adds "..." if too long
                                maxLines: 1,
                              ),
                            ),

                            // 2. Payment Type Badge (Only if known)
                            if (txn.type != "Unknown")
                              Container(
                                margin: const EdgeInsets.only(left: 8), // Gap
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(txn.type,
                                    style: const TextStyle(
                                        color: Constants.colorPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        // --- OVERFLOW FIX ENDS HERE ---

                        subtitle: Text(
                          "${txn.sender} • ${date.day}/${date.month} ${date.hour}:${date.minute}",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: Text(
                          "₹${txn.amount.toStringAsFixed(0)}", // Removed decimals for cleaner UI
                          style: const TextStyle(
                              color: Constants.colorPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Food':
        return Colors.green;
      case 'Travel':
        return Colors.blue;
      case 'Shopping':
        return Colors.amber;
      case 'Entertainment':
        return Colors.purple;
      case 'Bills':
        return Colors.red;
      case 'Grocery':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Food':
        return Icons.fastfood;
      case 'Travel':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills':
        return Icons.receipt;
      case 'Grocery':
        return Icons.local_grocery_store;
      default:
        return Icons.question_mark;
    }
  }
}
