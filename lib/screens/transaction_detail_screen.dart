import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/training_service.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';
<<<<<<< Updated upstream
=======
import 'interactive_training_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
>>>>>>> Stashed changes

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _selectedCategory;
  late TextEditingController _merchantController;
  final FocusNode _nodeFocus = FocusNode(); // <--- ADDED FOCUS NODE
  bool _isEditingNode = false; // <--- ADDED STATE FOR ANIMATION

  final TrainingService _trainingService = TrainingService();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _merchantController = TextEditingController(text: widget.transaction.merchant);
    _loadCategories();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _nodeFocus.dispose(); // Clean up focus node
    super.dispose();
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

    String updatedMerchant = _merchantController.text.trim();
    if (updatedMerchant.isNotEmpty && updatedMerchant != widget.transaction.merchant) {
      final db = await DBService().database;
      await db.update(
        Constants.tableTransactions,
        {'merchant': updatedMerchant},
        where: 'hash = ?',
        whereArgs: [widget.transaction.hash],
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("SYSTEM OVERRIDE: Log updated securely.", style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
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
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Constants.colorPrimary))
          : GestureDetector(
              // Tap outside to unfocus and collapse the terminal editor
              onTap: () {
                if (_isEditingNode) {
                  setState(() => _isEditingNode = false);
                  _nodeFocus.unfocus();
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. RAW SMS TERMINAL
                    const Text("> DECRYPTED_PAYLOAD",
                        style: TextStyle(
                            color: Constants.colorPrimary,
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Constants.colorPrimary),
                          boxShadow: [
                            BoxShadow(
                              color: Constants.colorPrimary.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ]),
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(
                            begin: 0, end: widget.transaction.body.length),
                        duration: const Duration(milliseconds: 1200),
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
                                fontSize: 15,
                                height: 1.5),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 2. TRANSACTION DETAILS
                    ...[
                      _buildFactRow("EXTRACTED_AMT", "₹${widget.transaction.amount}"),
                      _buildCyberNodeEditor(), // <--- NEW INNOVATIVE UI WIDGET
                      _buildFactRow("PAYMENT_VECTOR", widget.transaction.type),
                      _buildFactRow("TIMESTAMP", "${date.day}/${date.month} ${date.hour}:${date.minute}"),
                    ].animate(interval: 100.ms).fade(duration: 400.ms).slideY(begin: 0.1),

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
                      decoration: Constants.glassDecoration.copyWith(
                          borderRadius: BorderRadius.circular(8),
                      ),
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
                              fontSize: 16,
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
                    ),
<<<<<<< Updated upstream
                  )
                ],
=======

                    const SizedBox(height: 50),

                    // 4. ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TapScaleWrapper( 
                        onTap: _saveTraining,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: Constants.glowingBorderDecoration.copyWith(
                            color: Constants.colorPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.memory, color: Colors.black),
                              SizedBox(width: 8),
                              Text("EXECUTE OVERRIDE",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade().slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // 5. REGEX TRAINING BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TapScaleWrapper(
                        onTap: () {
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
                        child: Container(
                          alignment: Alignment.center,
                          decoration: Constants.glassDecoration.copyWith(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Constants.colorPrimary),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.model_training, color: Constants.colorPrimary),
                              SizedBox(width: 8),
                              Text("TRAIN REGEX PARSER",
                                  style: TextStyle(
                                      color: Constants.colorPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade().slideY(begin: 0.2)
                  ],
                ),
>>>>>>> Stashed changes
              ),
            ),
    );
  }

  // --- INNOVATIVE CYBER UI FOR TARGET NODE ---
  Widget _buildCyberNodeEditor() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(_isEditingNode ? 12 : 0),
      decoration: BoxDecoration(
        color: _isEditingNode ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isEditingNode ? Constants.colorPrimary : Colors.transparent,
          width: _isEditingNode ? 1 : 0,
        ),
        boxShadow: _isEditingNode
            ? [BoxShadow(color: Constants.colorPrimary.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)]
            : [],
      ),
      child: _isEditingNode
          ? Row( // EDIT MODE: Terminal Prompt
              children: [
                const Text(">", style: TextStyle(color: Constants.colorPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 12),
                Expanded( // Prevents overflow in edit mode
                  child: TextField(
                    controller: _merchantController,
                    focusNode: _nodeFocus,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: "ENTER_NODE_ID",
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onSubmitted: (_) {
                      setState(() => _isEditingNode = false);
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _isEditingNode = false);
                    _nodeFocus.unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Constants.colorPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.check, color: Constants.colorPrimary, size: 18),
                  ),
                ),
              ],
            ).animate().fade(duration: 200.ms)
          : Row( // VIEW MODE: Cyber Badge
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TARGET_NODE", style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
                const SizedBox(width: 16), // Buffer space
                Expanded( // <--- FIX: Forces the right side to respect screen bounds
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isEditingNode = true);
                        _nodeFocus.requestFocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Constants.colorPrimary.withOpacity(0.1),
                          border: Border.all(color: Constants.colorPrimary.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible( // <--- FIX: Allows text to shrink and truncate if it's too long
                              child: Text(
                                _merchantController.text.isEmpty ? "UNKNOWN_NODE" : _merchantController.text.toUpperCase(),
                                style: const TextStyle(color: Constants.colorPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                overflow: TextOverflow.ellipsis, // <--- FIX: Adds "..." instead of crashing
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_square, color: Constants.colorPrimary, size: 12),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2500.ms, color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Standard static fact row
  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
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