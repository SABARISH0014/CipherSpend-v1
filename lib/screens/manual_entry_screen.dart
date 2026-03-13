import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../services/training_service.dart';
import '../utils/constants.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();

  final SmsService _smsService = SmsService();
  final TrainingService _trainingService = TrainingService();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = "Others";
  String _selectedType = "Cash";

  List<String> _categories = [
    "Others",
    "Food",
    "Travel",
    "Shopping",
    "Bills",
    "Cash",
  ];
  final List<String> _paymentTypes = ["Cash", "UPI", "Card", "Bank Transfer"];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _trainingService.getCategories();
    if (cats.isNotEmpty) {
      setState(() {
        _categories = cats;
        if (!_categories.contains("Others")) _categories.add("Others");
        _selectedCategory = _categories.contains("Cash")
            ? "Cash"
            : _categories.first;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      double amount = double.parse(_amountController.text.trim());
      String merchant = _merchantController.text.trim();

      String hash = "MANUAL_${DateTime.now().millisecondsSinceEpoch}";

      final txn = TransactionModel(
        hash: hash,
        sender: "User",
        body: "Manual Entry: $merchant",
        amount: amount,
        category: _selectedCategory,
        type: _selectedType,
        merchant: merchant,
        timestamp: _selectedDate.millisecondsSinceEpoch,
      );

      await _smsService.saveTransaction(txn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Manual Record Injected",
              style: Constants.fontRegular.copyWith(
                color: Colors.black, 
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Constants.colorPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true); 
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
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- UI HELPER: Glassmorphism Input Decoration ---
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 0.5),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Constants.colorPrimary.withOpacity(0.5), width: 1.5)
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Constants.colorError.withOpacity(0.5), width: 1.5)
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: const BorderSide(color: Constants.colorError, width: 1.5)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "MANUAL ENTRY", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // 1. AMOUNT MODULE
                    _buildSectionHeader(Icons.data_usage_rounded, "FINANCIAL IMPACT").animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.none,
                      style: Constants.headerStyle.copyWith(
                        color: Constants.colorPrimary,
                        fontSize: 28,
                        letterSpacing: 1
                      ),
                      decoration: _buildInputDecoration("Amount (₹)", Icons.currency_rupee_rounded).copyWith(
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Constants.colorPrimary, size: 24),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required parameter missing';
                        if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Invalid numeric format';
                        return null;
                      },
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05),
                    
                    const SizedBox(height: 32),

                    // 2. MERCHANT MODULE
                    _buildSectionHeader(Icons.storefront_rounded, "TARGET NODE").animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _merchantController,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: _buildInputDecoration("Merchant / Reason", Icons.edit_note_rounded),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Node identity required';
                        return null;
                      },
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.05),
                    
                    const SizedBox(height: 32),

                    // 3. CLASSIFICATION MODULE
                    _buildSectionHeader(Icons.category_rounded, "CLASSIFICATION").animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        // Category Dropdown
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true, // [FIX] Prevents overflow by shrinking long text
                            value: _selectedCategory,
                            dropdownColor: Constants.colorSurface,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration("Category", Icons.folder_open_rounded),
                            items: _categories.map((String cat) {
                              return DropdownMenuItem(
                                value: cat, 
                                child: Text(cat.toUpperCase(), overflow: TextOverflow.ellipsis), // [FIX] Added ellipsis safety
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value!),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.05),
                        ),
                        
                        const SizedBox(width: 12), // Slightly reduced spacing to give text more room
                        
                        // Type Dropdown
                        Expanded(
                          flex: 5, // Balanced the flex to give "Bank Transfer" more room
                          child: DropdownButtonFormField<String>(
                            isExpanded: true, // [FIX] Prevents overflow
                            value: _selectedType,
                            dropdownColor: Constants.colorSurface,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration("Vector", Icons.account_tree_rounded),
                            items: _paymentTypes.map((String type) {
                              return DropdownMenuItem(
                                value: type, 
                                child: Text(type, overflow: TextOverflow.ellipsis), // [FIX] Added ellipsis safety
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedType = value!),
                          ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideX(begin: 0.05),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // 4. TEMPORAL DATA MODULE
                    _buildSectionHeader(Icons.access_time_rounded, "TEMPORAL DATA").animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 20),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Transaction Date",
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_calendar_rounded, color: Constants.colorPrimary, size: 18),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1),
                    
                    const SizedBox(height: 48),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.colorPrimary,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: Constants.colorPrimary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: const Text(
                          "INJECT RECORD",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        onPressed: _saveTransaction,
                      ),
                    ).animate().fadeIn(delay: 500.ms).scale(curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}