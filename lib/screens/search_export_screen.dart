import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';
import 'transaction_detail_screen.dart';

class SearchExportScreen extends StatefulWidget {
  const SearchExportScreen({super.key});

  @override
  State<SearchExportScreen> createState() => _SearchExportScreenState();
}

class _SearchExportScreenState extends State<SearchExportScreen> {
  final SmsService _smsService = SmsService();
  final TextEditingController _searchController = TextEditingController();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = "All";
  String _selectedType = "All";

  final List<String> _categories = [
    "All",
    "Food",
    "Travel",
    "Shopping",
    "Bills",
    "Entertainment",
    "Grocery",
    "Cash",
    "Investment",
    "Transfer",
    "Uncategorized"
  ];

  final List<String> _types = ["All", "UPI", "Debit", "Credit", "NetBanking", "Unknown"];

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    final results = await _smsService.searchTransactions(
      query: _searchController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      category: _selectedCategory,
      type: _selectedType,
    );

    if (mounted) {
      setState(() {
        _transactions = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterDialog() async {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;
    String tempCat = _selectedCategory;
    String tempType = _selectedType;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Constants.colorSurface,
            title: const Text("Filter Transactions", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Selector
                  const Text("Date Range", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Constants.colorPrimary,
                                onPrimary: Colors.black,
                                surface: Constants.colorSurface,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tempStart = picked.start;
                          tempEnd = picked.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range, color: Constants.colorPrimary),
                    label: Text(
                      tempStart == null
                          ? "Select Range"
                          : "${DateFormat('MMM dd, yyyy').format(tempStart!)} - ${DateFormat('MMM dd, yyyy').format(tempEnd!)}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (tempStart != null)
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          tempStart = null;
                          tempEnd = null;
                        });
                      },
                      child: const Text("Clear Dates", style: TextStyle(color: Colors.redAccent)),
                    ),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  const Text("Category", style: TextStyle(color: Colors.grey)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempCat,
                    dropdownColor: Constants.colorSurface,
                    items: _categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tempCat = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Type Dropdown
                  const Text("Payment Type", style: TextStyle(color: Colors.grey)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempType,
                    dropdownColor: Constants.colorSurface,
                    items: _types.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tempType = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Constants.colorPrimary),
                onPressed: () {
                  setState(() {
                    _startDate = tempStart;
                    _endDate = tempEnd;
                    _selectedCategory = tempCat;
                    _selectedType = tempType;
                  });
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text("APPLY", style: TextStyle(color: Colors.black)),
              )
            ],
          );
        });
      },
    );
  }

  Future<void> _exportToCSV() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No transactions to export.")),
      );
      return;
    }

    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            var manageStatus = await Permission.manageExternalStorage.status;
            if (!manageStatus.isGranted) {
              manageStatus = await Permission.manageExternalStorage.request();
            }
            if (!manageStatus.isGranted) {
              throw Exception("Storage permission is required to save the export.");
            }
          }
        }
      }

      // Build CSV String
      StringBuffer csvData = StringBuffer();
      // Headers
      csvData.writeln("Date,Merchant,Amount,Category,Type,Hash,Sender");

      // Rows
      for (var txn in _transactions) {
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(txn.timestamp));
        // Escape merchants with commas
        String safeMerchant = txn.merchant.contains(',') ? '"${txn.merchant}"' : txn.merchant;
        String safeCategory = txn.category.contains(',') ? '"${txn.category}"' : txn.category;
        
        csvData.writeln("$dateStr,$safeMerchant,${txn.amount},$safeCategory,${txn.type},${txn.hash},${txn.sender}");
      }

      // Save to directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        // Fallback if somehow that doesn't exist
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) throw Exception("Could not access downloads directory.");
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String path = '${directory.path}/CipherSpend_Export_$timestamp.csv';
      
      final File file = File(path);
      await file.writeAsString(csvData.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export saved to: $path"),
            backgroundColor: Constants.colorPrimary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    // Determine how many active filters we have
    int filterCount = 0;
    if (_startDate != null) filterCount++;
    if (_selectedCategory != "All") filterCount++;
    if (_selectedType != "All") filterCount++;

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Search & Export"),
        backgroundColor: Constants.colorSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Constants.colorPrimary),
            tooltip: 'Export CSV',
            onPressed: _exportToCSV,
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search merchant or description...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Constants.colorSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Constants.colorSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list, color: Constants.colorPrimary),
                        onPressed: _openFilterDialog,
                      ),
                    ),
                    if (filterCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            filterCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                  ],
                )
              ],
            ),
          ),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_transactions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 60, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text("No transactions found", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final txn = _transactions[index];
                  final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);
                  
                  return Card(
                    color: Constants.colorSurface,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      onTap: () async {
                        bool? updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(transaction: txn),
                          ),
                        );
                        if (updated == true) _performSearch();
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
                        txn.merchant,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${txn.category} • ${DateFormat('MMM dd, yyyy').format(date)}",
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
