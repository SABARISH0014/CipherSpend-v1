import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import '../models/transaction_model.dart';
import '../services/training_service.dart';
import '../utils/constants.dart';
import 'interactive_training_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _selectedCategory;
  late String _currentMerchant;
  
  final TrainingService _trainingService = TrainingService();
  List<String> _categories = [];
  bool _isLoading = true;
  bool _wasModified = false; 

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _currentMerchant = widget.transaction.merchant;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _trainingService.getCategories();
    setState(() {
      _categories = cats;
      if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveTraining() async {
    setState(() => _isLoading = true);
    await _trainingService.trainTransaction(
        widget.transaction.hash, _selectedCategory);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("SYSTEM OVERRIDE: Shifted to $_selectedCategory", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Constants.colorPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2), // Added duration
      ));
      Navigator.pop(context, true);
    }
  }

  Future<void> _showEditMerchantDialog() async {
    final TextEditingController controller = TextEditingController(text: _currentMerchant);
    
    final List<String> payloadTokens = widget.transaction.body
        .split(RegExp(r'\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final String? newMerchant = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: Constants.glassDecoration.copyWith(
                  border: Border.all(color: Constants.colorAccent.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Constants.colorAccent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub_rounded, color: Constants.colorAccent),
                        const SizedBox(width: 10),
                        Text("Extract Target Node", style: Constants.headerStyle.copyWith(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "Merchant Name",
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black45,
                        prefixIcon: const Icon(Icons.storefront_rounded, color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.backspace_rounded, color: Constants.colorError, size: 20),
                          tooltip: "Clear Buffer",
                          onPressed: () {
                            controller.clear();
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Constants.colorAccent.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Constants.colorAccent, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          "TAP FRAGMENTS TO EXTRACT", 
                          style: Constants.fontRegular.copyWith(fontSize: 10, color: Constants.colorAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      height: 160, 
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: payloadTokens.map((token) {
                            return InkWell(
                              onTap: () {
                                final currentText = controller.text.trim();
                                if (currentText.isEmpty) {
                                  controller.text = token;
                                } else {
                                  controller.text = "$currentText $token";
                                }
                                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Constants.colorAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Constants.colorAccent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  token, 
                                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("CANCEL", style: Constants.fontRegular.copyWith(color: Colors.white70)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // <-- Adjusted padding here
                            backgroundColor: Constants.colorAccent,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shadowColor: Constants.colorAccent.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                          child: const Text("UPDATE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms),
            );
          }
        );
      },
    );

    if (newMerchant != null && newMerchant.isNotEmpty && newMerchant != _currentMerchant) {
      setState(() => _isLoading = true);
      await _trainingService.updateMerchantName(widget.transaction.hash, newMerchant);
      setState(() {
        _currentMerchant = newMerchant;
        _wasModified = true;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("TARGET_NODE updated to $_currentMerchant", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Constants.colorAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2), // Added duration
          ),
        );
      }
    }
  }

  // --- UI HELPER: Micro Header ---
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Constants.colorPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(widget.transaction.timestamp);

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _wasModified);
        return false;
      },
      child: Scaffold(
        backgroundColor: Constants.colorBackground,
        appBar: AppBar(
          title: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text("NEURAL OVERRIDE", style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0, 
          surfaceTintColor: Colors.transparent, 
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context, _wasModified),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Constants.colorPrimary))
            : SingleChildScrollView(
                // [BALANCED]: Medium padding
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // 1. RAW SMS TERMINAL
                    _buildSectionHeader(Icons.terminal_rounded, "DECRYPTED_PAYLOAD").animate().fadeIn().slideX(),
                    const SizedBox(height: 12), // [BALANCED]

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18), // [BALANCED]
                      decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Constants.colorPrimary.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]),
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(
                            begin: 0, end: widget.transaction.body.length),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          String visibleText =
                              widget.transaction.body.substring(0, value);
                          String cursor =
                              value < widget.transaction.body.length ? "█" : "";
                          return Text(
                            visibleText + cursor,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Constants.colorPrimary,
                                fontSize: 14, // [BALANCED] Font back to 14
                                height: 1.5), 
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 200.ms).scaleY(alignment: Alignment.topCenter),

                    const SizedBox(height: 28), // [BALANCED]

                    // 2. TRANSACTION DETAILS (Wrapped in Glassmorphism)
                    _buildSectionHeader(Icons.analytics_rounded, "EXTRACTED_METADATA").animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 12), // [BALANCED]
                    
                    Container(
                      padding: const EdgeInsets.all(18), // [BALANCED]
                      decoration: Constants.glassDecoration.copyWith(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: []
                      ),
                      child: Column(
                        children: [
                          _buildFactRow("EXTRACTED_AMT", "₹${widget.transaction.amount}"),
                          const Divider(color: Colors.white10, height: 20), // [BALANCED]
                          _buildFactRow("TARGET_NODE", _currentMerchant, onEdit: _showEditMerchantDialog, highlightColor: Constants.colorAccent),
                          const Divider(color: Colors.white10, height: 20), // [BALANCED]
                          _buildFactRow("PAYMENT_VECTOR", widget.transaction.type),
                          const Divider(color: Colors.white10, height: 20), // [BALANCED]
                          _buildFactRow("TIMESTAMP", "${date.day}/${date.month} ${date.hour}:${date.minute}"),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 28), // [BALANCED]

                    // 3. TRAINING INPUT
                    _buildSectionHeader(Icons.category_rounded, "INJECT_NEW_CATEGORY").animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 12), // [BALANCED]

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: Constants.glassDecoration.copyWith(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: []
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categories.contains(_selectedCategory)
                              ? _selectedCategory
                              : null,
                          isExpanded: true,
                          dropdownColor: Constants.colorSurface,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: Constants.colorPrimary),
                          style: Constants.fontRegular.copyWith(
                              color: Colors.white,
                              fontSize: 16, // [BALANCED] Font back up to 16
                              fontWeight: FontWeight.bold),
                          items: _categories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() => _selectedCategory = newValue!);
                          },
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                    const SizedBox(height: 36), // [BALANCED]

                    // 4. ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54, // [BALANCED] Raised from 52 to 54
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.colorPrimary,
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: Constants.colorPrimary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.sync_rounded, size: 20),
                        onPressed: _saveTraining,
                        label: const Text("EXECUTE OVERRIDE",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 14)), // [BALANCED]
                      ),
                    ).animate().fadeIn(delay: 700.ms).scale(),

                    const SizedBox(height: 14), // [BALANCED]

                    // 5. REGEX TRAINING BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54, // [BALANCED] Raised from 52 to 54
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Constants.colorAccent,
                            side: const BorderSide(color: Constants.colorAccent, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.model_training_rounded, size: 20),
                        onPressed: () {
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing before routing!
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InteractiveTrainingScreen(
            smsBody: widget.transaction.body,
            sender: widget.transaction.sender,
          ),
        ),
      );
    },
                        label: const Text("TRAIN REGEX PARSER",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 14)), // [BALANCED]
                      ),
                    ).animate().fadeIn(delay: 800.ms).scale(),
                    
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFactRow(String label, String value, {VoidCallback? onEdit, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: Constants.fontRegular.copyWith(fontSize: 12, color: Colors.white70)), // [BALANCED]
        const SizedBox(width: 16), 
        Expanded(
          child: GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: highlightColor ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 14), // [BALANCED] 
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded,
                      color: highlightColor ?? Constants.colorPrimary, size: 16),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }
}