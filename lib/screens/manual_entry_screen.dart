import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<void> _saveTransaction() async {
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
                        labelText: "Amount (₹)",
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.currency_rupee,
                          color: Constants.colorPrimary,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter an amount';
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0)
                          return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // MERCHANT INPUT
                    TextFormField(
                      controller: _merchantController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Merchant / Reason",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.store, color: Colors.grey),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Please enter a merchant or reason';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // CATEGORY DROPDOWN
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: Constants.colorSurface,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Category",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.category,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _categories.map((String cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value!),
                    ),
                    const SizedBox(height: 20),

                    // TYPE DROPDOWN
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      dropdownColor: Constants.colorSurface,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Payment Mode",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _paymentTypes.map((String type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value!),
                    ),
                    const SizedBox(height: 20),

                    // DATE PICKER
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Constants.colorSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Transaction Date",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                  ).format(_selectedDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.colorPrimary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          "SAVE EXPENSE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        onPressed: _saveTransaction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
