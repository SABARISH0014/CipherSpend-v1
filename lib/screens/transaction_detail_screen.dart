import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/training_service.dart';
import '../utils/constants.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _selectedCategory;
  final TrainingService _trainingService = TrainingService();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _trainingService.getCategories();
    setState(() {
      _categories = cats;
      // Safety check: ensure selected category exists in list
      if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveTraining() async {
    setState(() => _isLoading = true);
    // Update DB
    await _trainingService.trainTransaction(
        widget.transaction.hash, _selectedCategory);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Category updated to $_selectedCategory")));
      Navigator.pop(
          context, true); // Return 'true' to trigger dashboard refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(widget.transaction.timestamp);

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Train CipherSpend"),
        backgroundColor: Constants.colorSurface,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. RAW SMS (The Evidence)
                  const Text("RAW SMS EVIDENCE",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Constants.colorSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10)),
                    child: Text(
                      widget.transaction.body,
                      style: const TextStyle(
                          fontFamily: 'monospace', color: Colors.white70),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. TRANSACTION DETAILS
                  _buildFactRow("Amount", "₹${widget.transaction.amount}"),
                  _buildFactRow("Sender", widget.transaction.sender),
                  _buildFactRow("Type", widget.transaction.type),
                  _buildFactRow("Date",
                      "${date.day}/${date.month} ${date.hour}:${date.minute}"),

                  const SizedBox(height: 30),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 20),

                  // 3. TRAINING INPUT
                  const Text("CORRECT CATEGORY",
                      style: TextStyle(
                          color: Constants.colorPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: Constants.colorSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Constants.colorPrimary.withOpacity(0.5))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : null,
                        isExpanded: true,
                        dropdownColor: Constants.colorSurface,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Constants.colorPrimary),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        items: _categories.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() => _selectedCategory = newValue!);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 4. ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.colorPrimary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _saveTraining,
                      child: const Text("Confirm & Train",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
