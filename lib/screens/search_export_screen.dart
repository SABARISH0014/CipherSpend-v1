import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';
import 'transaction_detail_screen.dart';

class SearchExportScreen extends StatefulWidget {
  final bool isGlobalSyncing;
  final int refreshTrigger;
  final VoidCallback? onReturnToDashboard;

  const SearchExportScreen({
    super.key, 
    this.isGlobalSyncing = false,
    this.refreshTrigger = 0,
    this.onReturnToDashboard,
  });

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
    "All", "Food", "Travel", "Shopping", "Bills", 
    "Entertainment", "Grocery", "Cash", "Investment", 
    "Transfer", "Uncategorized"
  ];

  final List<String> _types = ["All", "UPI", "Debit", "Credit", "NetBanking", "Unknown"];

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void didUpdateWidget(SearchExportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGlobalSyncing && !widget.isGlobalSyncing) {
      _performSearch();
    } else if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _performSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    // 1. FIX THE END DATE BUG
    // Push the end date to 23:59:59 so it includes the entire final day
    DateTime? adjustedEndDate = _endDate;
    if (adjustedEndDate != null) {
      adjustedEndDate = DateTime(
        adjustedEndDate.year, 
        adjustedEndDate.month, 
        adjustedEndDate.day, 
        23, 59, 59
      );
    }

    // 2. SAFELY HANDLE "All"
    // If the user selects "All", we pass 'null' to the database so it knows to skip that filter
    String? queryCat = _selectedCategory == "All" ? null : _selectedCategory;
    String? queryType = _selectedType == "All" ? null : _selectedType;

    try {
      final results = await _smsService.searchTransactions(
        query: _searchController.text.trim(),
        startDate: _startDate,
        endDate: adjustedEndDate,
        category: queryCat,
        type: queryType,
      );

      if (mounted) {
        setState(() {
          _transactions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          return BackdropFilter(
            filter: Constants.glassBlur,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: Constants.glassDecoration,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.filter_alt_rounded, color: Constants.colorAccent),
                          const SizedBox(width: 10),
                          Text("Filter Ledger", style: Constants.headerStyle.copyWith(fontSize: 20)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Date Range Selector
                      Text("Date Range", style: Constants.fontRegular),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                                    surface: Constants.colorBackground,
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
                        icon: const Icon(Icons.date_range_rounded, color: Constants.colorPrimary),
                        label: Text(
                          tempStart == null
                              ? "Select Range"
                              : "${DateFormat('MMM dd, yyyy').format(tempStart!)} - ${DateFormat('MMM dd, yyyy').format(tempEnd!)}",
                          style: Constants.fontRegular.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (tempStart != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                tempStart = null;
                                tempEnd = null;
                              });
                            },
                            child: const Text("Clear Dates", style: TextStyle(color: Constants.colorError)),
                          ),
                        ),
                      const SizedBox(height: 20),
                      
                      // Category Dropdown
                      Text("Category", style: Constants.fontRegular),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: tempCat,
                            dropdownColor: Constants.colorSurface,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Constants.colorPrimary),
                            items: _categories.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c, style: Constants.fontRegular.copyWith(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => tempCat = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Type Dropdown
                      Text("Payment Vector", style: Constants.fontRegular),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: tempType,
                            dropdownColor: Constants.colorSurface,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Constants.colorPrimary),
                            items: _types.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(t, style: Constants.fontRegular.copyWith(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => tempType = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("CANCEL", style: Constants.fontRegular),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: Constants.colorPrimary,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              shadowColor: Constants.colorPrimary.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
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
                            child: const Text("APPLY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ).animate().scale(curve: Curves.easeOutCubic, duration: 400.ms).fadeIn(),
          );
        });
      },
    );
  }

// Update _exportToCSV:
  Future<void> _exportToCSV() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No transactions to export.", style: Constants.fontRegular.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2), // Added duration
        ),
      );
      return;
    }

    try {
      // Build CSV String
      StringBuffer csvData = StringBuffer();
      // Headers
      csvData.writeln("Date,Merchant,Amount,Category,Type,Hash,Sender");

      // Rows
      for (var txn in _transactions) {
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(txn.timestamp));
        String safeMerchant = txn.merchant.contains(',') ? '"${txn.merchant}"' : txn.merchant;
        String safeCategory = txn.category.contains(',') ? '"${txn.category}"' : txn.category;
        
        csvData.writeln("$dateStr,$safeMerchant,${txn.amount},$safeCategory,${txn.type},${txn.hash},${txn.sender}");
      }

      // 1. Save to hidden temporary cache first
      final directory = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = 'CipherSpend_Export_$timestamp.csv';
      final String tempFilePath = '${directory.path}/$fileName';
      
      final File tempFile = File(tempFilePath);
      await tempFile.writeAsString(csvData.toString());

      // 2. Trigger native Android Save Dialog directly to Downloads folder
      if (mounted) {
        final params = SaveFileDialogParams(
          sourceFilePath: tempFile.path,
          fileName: fileName,
        );
        
        // This opens the Android file picker and returns the path if the user saves it
        final filePath = await FlutterFileDialog.saveFile(params: params);

// 3. Show Success Message if they didn't cancel
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully saved to Downloads folder!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Constants.colorPrimary,
            duration: Duration(seconds: 2), // Reduced from 4 to 2
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Constants.colorError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3), // Shortened duration
          ),
        );
      }
    }
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

  // --- CYBER-NODE TRANSACTION CARDS (Ported from Dashboard) ---
  Widget _buildTransactionItem(TransactionModel txn, int index) {
    final date = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);
    final catColor = _getCategoryColor(txn.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.03),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
    ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing before routing!
    bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: txn)),
    );
    if (updated == true) _performSearch();
  },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Constants.colorSurface.withValues(alpha: 0.6), 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1), 
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
                // Glowing Neon Strip
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
                
                // Category Icon
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      fontSize: 18, 
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
    ).animate().fade(duration: 400.ms, delay: (40 * index).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  // --- SCANNING RADAR EMPTY STATE ---
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
              Icon(Icons.search_off_rounded, size: 50, color: Constants.colorPrimary.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Text("NO MATCHES FOUND", style: Constants.headerStyle.copyWith(color: Constants.colorPrimary.withValues(alpha: 0.8), letterSpacing: 4, fontSize: 14)),
          const SizedBox(height: 8),
          Text("Adjust your filters or query\nto decrypt more records.", textAlign: TextAlign.center, style: Constants.subHeaderStyle.copyWith(fontSize: 11)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGlobalSyncing) return const SizedBox.shrink();

    int filterCount = 0;
    if (_startDate != null) filterCount++;
    if (_selectedCategory != "All") filterCount++;
    if (_selectedType != "All") filterCount++;

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false, 
        leading: widget.onReturnToDashboard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: widget.onReturnToDashboard,
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "SEARCH & EXPORT", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Constants.colorPrimary, size: 24),
            tooltip: 'Export CSV',
            onPressed: _exportToCSV,
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -2, end: 2, duration: 1.seconds),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: Constants.glassDecoration.copyWith(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: Constants.fontRegular.copyWith(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
  hintText: "Search registry...",
  hintStyle: Constants.fontRegular.copyWith(color: Colors.white30, letterSpacing: 1), // <-- FIXED
  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
  border: InputBorder.none,
  contentPadding: const EdgeInsets.symmetric(vertical: 16),
),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.05),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    Container(
                      decoration: Constants.glassDecoration.copyWith(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: IconButton(
                        padding: const EdgeInsets.all(14),
                        icon: const Icon(Icons.filter_list_rounded, color: Constants.colorAccent, size: 20),
                        onPressed: _openFilterDialog,
                      ),
                    ),
                    if (filterCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Constants.colorError,
                            shape: BoxShape.circle,
                            border: Border.all(color: Constants.colorBackground, width: 2),
                          ),
                          child: Text(
                            filterCount.toString(),
                            style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ).animate().scale(curve: Curves.bounceOut),
                      )
                  ],
                ).animate().fadeIn().slideX(begin: 0.05)
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Constants.colorPrimary)))
          else if (_transactions.isEmpty)
            Expanded(child: _buildEmptyState())
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                physics: const BouncingScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  return _buildTransactionItem(_transactions[index], index);
                },
              ),
            ),
        ],
      ),
    );
  }
}