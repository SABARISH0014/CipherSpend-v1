import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../services/training_service.dart';
import '../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  // Load the AI categories dynamically so the dropdown matches your labels.json
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
              surface: Constants.colorSurface,
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

  Future<void> _saveExpense() async {
    // Renamed from _saveTransaction
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      double amount = double.parse(_amountController.text.trim());
      String merchant = _merchantController.text.trim();

      // Create a unique hash for manual entries
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
          const SnackBar(
            content: Text("✅ Transaction Logged Manually"),
            backgroundColor: Constants.colorPrimary,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to signal a refresh is needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Log Expense"),
        backgroundColor: Constants.colorSurface,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AMOUNT INPUT
                    const Text("Amount",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: "e.g., 500.00", // Changed to hintText
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Constants.colorPrimary),
                        ),
                      ),
                      validator: (value) => value!.isEmpty
                          ? 'Enter amount'
                          : (double.tryParse(value) == null ||
                                  double.parse(value) <= 0)
                              ? 'Enter a valid number'
                              : null,
                    ),
                    const SizedBox(height: 20),

                    // MERCHANT
                    const Text("Merchant / Concept",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _merchantController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g., Zomato, Uber, Grocery...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Constants.colorPrimary),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter merchant name' : null,
                    ),
                    const SizedBox(height: 20),

                    // CATEGORY
                    const Text("Category",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: Constants.glassDecoration.copyWith(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: Constants.colorSurface,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: _categories.map((String cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // TYPE (CASH, DEBIT, CREDIT)
                    const Text("Payment Type",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: Constants.glassDecoration.copyWith(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          dropdownColor: Constants.colorSurface,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: _paymentTypes.map((String type) {
                            return DropdownMenuItem(
                                value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedType = value!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DATE PICKER
                    const Text("Transaction Date",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TapScaleWrapper(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: Constants.glassDecoration.copyWith(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(Icons.calendar_today,
                                color: Constants.colorPrimary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: TapScaleWrapper(
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            _saveExpense();
                          }
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: Constants.glowingBorderDecoration.copyWith(
                            color: Constants.colorPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "SAVE EXPENSE",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1),
                ),
              ),
            ),
    );
  }
}
