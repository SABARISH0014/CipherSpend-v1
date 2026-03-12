import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("SYSTEM OVERRIDE: Shifted to $_selectedCategory"),
        backgroundColor: Constants.colorPrimary,
      ));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(widget.transaction.timestamp);

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Neural Override"),
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
                  // 1. RAW SMS TERMINAL (The Evidence)
                  const Text("> DECRYPTED_PAYLOAD",
                      style: TextStyle(
                          color: Constants.colorPrimary,
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Glowing Terminal Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.black, // True black for terminal
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Constants.colorPrimary),
                        boxShadow: [
                          BoxShadow(
                            color: Constants.colorPrimary.withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]),
                    // The Typing Animation Effect
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(
                          begin: 0, end: widget.transaction.body.length),
                      duration: const Duration(milliseconds: 1200),
                      builder: (context, value, child) {
                        String visibleText =
                            widget.transaction.body.substring(0, value);
                        // Add a blinking block cursor at the end while typing
                        String cursor =
                            value < widget.transaction.body.length ? "█" : "";
                        return Text(
                          visibleText + cursor,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Constants.colorPrimary,
                              fontSize: 15,
                              height: 1.5),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. TRANSACTION DETAILS
                  _buildFactRow(
                      "EXTRACTED_AMT", "₹${widget.transaction.amount}"),
                  _buildFactRow("TARGET_NODE", widget.transaction.merchant),
                  _buildFactRow("PAYMENT_VECTOR", widget.transaction.type),
                  _buildFactRow("TIMESTAMP",
                      "${date.day}/${date.month} ${date.hour}:${date.minute}"),

                  const SizedBox(height: 30),
                  Divider(color: Constants.colorPrimary.withOpacity(0.3)),
                  const SizedBox(height: 20),

                  // 3. TRAINING INPUT
                  const Text("> INJECT_NEW_CATEGORY",
                      style: TextStyle(
                          color: Constants.colorPrimary,
                          fontFamily: 'monospace',
                          fontSize: 14,
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
                        style: const TextStyle(
                            color: Constants.colorPrimary,
                            fontFamily: 'monospace',
                            fontSize: 16),
                        items: _categories.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.toUpperCase()), // Hackery caps
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
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.colorPrimary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      icon: const Icon(Icons.memory),
                      onPressed: _saveTraining,
                      label: const Text("EXECUTE OVERRIDE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. REGEX TRAINING BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Constants.colorPrimary,
                          side: const BorderSide(color: Constants.colorPrimary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      icon: const Icon(Icons.model_training),
                      onPressed: () {
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
                              fontFamily: 'monospace',
                              letterSpacing: 2)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  // [FIXED] Added Expanded and CrossAxisAlignment to prevent RenderFlex overflows on long names
  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.start, // Aligns text to top if it wraps
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontFamily: 'monospace')),
          const SizedBox(
              width: 16), // Ensures label and value don't crash into each other
          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.right, // Keeps it neatly aligned to the right side
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
