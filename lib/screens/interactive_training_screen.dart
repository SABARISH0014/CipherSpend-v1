import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InteractiveTrainingScreen extends StatefulWidget {
  final String smsBody;
  final String sender;

  const InteractiveTrainingScreen({
    super.key,
    required this.smsBody,
    required this.sender,
  });

  @override
  State<InteractiveTrainingScreen> createState() =>
      _InteractiveTrainingScreenState();
}

class _InteractiveTrainingScreenState extends State<InteractiveTrainingScreen> {
  late List<String> _words;
  int? _amountIndex;
  List<int> _merchantIndices = [];

  @override
  void initState() {
    super.initState();
    // A simpler way: just split by simple space
    _words = widget.smsBody.split(' ');
  }

  void _showTaggingBottomSheet(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: Constants.glassDecoration.copyWith(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Identify this token:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money, color: Constants.colorPrimary),
                  title: const Text("Amount", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (_amountIndex == index) {
                        _amountIndex = null;
                      } else {
                        _amountIndex = index;
                      }
                      
                      if (_merchantIndices.contains(index)) {
                        _merchantIndices.remove(index);
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storefront, color: Constants.colorPrimary),
                  title: const Text("Merchant", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (_merchantIndices.contains(index)) {
                        _merchantIndices.remove(index);
                      } else {
                        _merchantIndices.add(index);
                        _merchantIndices.sort(); // Keep them in order for regex building
                        
                        // Auto-fill gaps if we have more than one word selected
                        if (_merchantIndices.length > 1) {
                           int min = _merchantIndices.first;
                           int max = _merchantIndices.last;
                           _merchantIndices.clear();
                           for (int i = min; i <= max; i++) {
                             _merchantIndices.add(i);
                             if (_amountIndex == i) _amountIndex = null;
                           }
                        }
                      }

                      if (_amountIndex == index) _amountIndex = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text("Ignore / Static Text", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (_amountIndex == index) _amountIndex = null;
                      if (_merchantIndices.contains(index)) _merchantIndices.remove(index);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ).animate().fade().slideY(begin: 0.1, duration: 200.ms),
          ),
        );
      },
    );
  }

  void _showGroupTaggingBottomSheet(int start, int end) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: Constants.glassDecoration.copyWith(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Identify this group:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text("Ignore / Static Text (Remove Tag)", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      for (int i = start; i <= end; i++) {
                        _merchantIndices.remove(i);
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ).animate().fade().slideY(begin: 0.1, duration: 200.ms),
          ),
        );
      },
    );
  }

  Future<void> _generateAndSaveRule() async {
    if (_amountIndex == null || _merchantIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an Amount and at least one Merchant word")),
      );
      return;
    }

    List<String> regexParts = [];
    bool isInsideMerchantGroup = false;

    for (int i = 0; i < _words.length; i++) {
      if (i == _amountIndex) {
        regexParts.add(r'(?<amount>\d+(?:,\d+)*(?:\.\d+)?)');
        isInsideMerchantGroup = false;
      } else if (_merchantIndices.contains(i)) {
        if (!isInsideMerchantGroup) {
          // Check if this merchant group is the very last element being processed.
          bool isLast = true;
          for (int j = i + 1; j < _words.length; j++) {
             if (!_merchantIndices.contains(j)) {
                 isLast = false;
                 break;
             }
          }

          if (isLast) {
              // Greedy match if it's the end of the text
              regexParts.add(r'(?<merchant>.+)');
          } else {
              // Lazy match if there are static words following
              regexParts.add(r'(?<merchant>.+?)');
          }
          isInsideMerchantGroup = true;
        } else {
            // Already started the capture group. Do nothing.
        }
      } else {
        isInsideMerchantGroup = false;
        regexParts.add(RegExp.escape(_words[i]));
      }
    }

    // Join with spaces, optionally handling variable spacing
    String finalRegex = regexParts.join(r'\s+');

    try {
      await DBService().saveCustomRule(widget.sender, finalRegex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rule saved successfully!", style: TextStyle(color: Colors.black)),
            backgroundColor: Constants.colorPrimary,
          ),
        );
        Navigator.pop(context, true); // Pop back to debugger screen with success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving rule: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Train Parser"),
        backgroundColor: Constants.colorSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tap on the words below to identify the 'Amount' and 'Merchant'.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List.generate(_words.length, (index) {
                if (_merchantIndices.contains(index)) {
                  // Find the end of this contiguous group
                  if (index > 0 && _merchantIndices.contains(index - 1)) {
                    return const SizedBox.shrink(); // Handled by the first token of the group
                  }

                  int start = index;
                  int end = index;
                  while (end + 1 < _words.length && _merchantIndices.contains(end + 1)) {
                    end++;
                  }
                  
                  String groupText = _words.sublist(start, end + 1).join(' ');
                  return ActionChip(
                    backgroundColor: Colors.blueAccent,
                    label: Text("$groupText [Merchant]", style: const TextStyle(color: Colors.white)),
                    onPressed: () => _showGroupTaggingBottomSheet(start, end),
                  ).animate().scale(delay: (20 * index).ms).fade();
                } else {
                  // Normal single token rendering for Amount or regular word
                  Color chipColor = Constants.colorSurface;
                  Color textColor = Colors.white;
                  String tag = "";

                  if (index == _amountIndex) {
                    chipColor = Constants.colorPrimary;
                    textColor = Colors.black;
                    tag = " [Amount]";
                  }

                  return ActionChip(
                    backgroundColor: chipColor,
                    label: Text(
                      "${_words[index]}$tag",
                      style: TextStyle(color: textColor),
                    ),
                    onPressed: () => _showTaggingBottomSheet(index),
                  ).animate().scale(delay: (20 * index).ms).fade();
                }
              }),
            ),
          ].animate(interval: 100.ms).fade().slideY(begin: 0.05),
        ),
      ),
      floatingActionButton: (_amountIndex != null && _merchantIndices.isNotEmpty)
          ? GestureDetector(
              onTap: _generateAndSaveRule,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: Constants.glowingBorderDecoration.copyWith(
                  color: Constants.colorPrimary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      "Generate Rule",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ).animate().scale(begin: const Offset(0, 0), curve: Curves.easeOutBack)
          : null,
    );
  }
}