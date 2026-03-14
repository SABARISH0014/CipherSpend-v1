import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';

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
  final List<int> _merchantIndices = [];

  @override
  void initState() {
    super.initState();
    // Split by spaces, keep consecutive spaces attached to previous word for reconstruction
    _words = widget.smsBody.split(' ');
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

  void _showTaggingBottomSheet(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: Constants.glassBlur,
          child: Container(
            decoration: Constants.glassDecoration.copyWith(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              // [FIX] Changed to uniform Border.all
              border: Border.all(color: Constants.colorAccent.withValues(alpha: 0.3), width: 1.5), 
              boxShadow: [
                BoxShadow(color: Constants.colorAccent.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5)
              ]
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text("IDENTIFY FRAGMENT", style: Constants.fontRegular.copyWith(fontSize: 10, color: Constants.colorAccent, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            "'${_words[index]}'",
                            textAlign: TextAlign.center,
                            style: Constants.headerStyle.copyWith(fontSize: 20, fontFamily: 'monospace', color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        _buildActionTile(
                          Icons.data_usage_rounded,
                          "Extract as Amount",
                          Constants.colorPrimary,
                          () {
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
                        _buildActionTile(
                          Icons.storefront_rounded,
                          "Extract as Target Node",
                          Constants.colorAccent,
                          () {
                            setState(() {
                              if (_merchantIndices.contains(index)) {
                                _merchantIndices.remove(index);
                              } else {
                                _merchantIndices.add(index);
                                _merchantIndices.sort(); 

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
                        _buildActionTile(
                          Icons.do_not_disturb_on_total_silence_rounded,
                          "Ignore (Static String)",
                          Colors.white38,
                          () {
                            setState(() {
                              if (_amountIndex == index) _amountIndex = null;
                              if (_merchantIndices.contains(index)) {
                                _merchantIndices.remove(index);
                              }
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ).animate().slideY(begin: 1.0, curve: Curves.easeOutCubic, duration: 400.ms);
      },
    );
  }

  void _showGroupTaggingBottomSheet(int start, int end) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: Constants.glassBlur,
          child: Container(
            decoration: Constants.glassDecoration.copyWith(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              // [FIX] Changed to uniform Border.all
              border: Border.all(color: Constants.colorError.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [BoxShadow(color: Constants.colorError.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5)]
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "MODIFY NODE CLUSTER",
                      style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 1.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildActionTile(
                      Icons.cancel_rounded,
                      "Purge Target Tag",
                      Constants.colorError,
                      () {
                        setState(() {
                          for (int i = start; i <= end; i++) {
                            _merchantIndices.remove(i);
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ).animate().slideY(begin: 1.0, curve: Curves.easeOutCubic, duration: 400.ms);
      },
    );
  }

  // --- UI HELPER: Cyber-Styled Bottom Sheet Action Tiles ---
  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: Constants.fontRegular.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _generateAndSaveRule() async {
    if (_amountIndex == null || _merchantIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Protocol incomplete: Select Amount and Target Node.",
            style: Constants.fontRegular.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    List<String> regexParts = [];
    bool isInsideMerchantGroup = false;

    for (int i = 0; i < _words.length; i++) {
      if (i == _amountIndex) {
        regexParts.add(r'(?<amount>\d+(?:,\d+)*(?:\.\d+)?)');
      } else if (_merchantIndices.contains(i)) {
        if (!isInsideMerchantGroup) {
          bool isLast = true;
          for (int j = i; j < _words.length; j++) {
            if (!_merchantIndices.contains(j)) {
              isLast = false;
              break;
            }
          }

          if (isLast) {
            regexParts.add(r'(?<merchant>.+)');
          } else {
            regexParts.add(r'(?<merchant>.+?)');
          }
          isInsideMerchantGroup = true;
        }
      } else {
        isInsideMerchantGroup = false;
        regexParts.add(RegExp.escape(_words[i]));
      }
    }

    String finalRegex = regexParts.join(r'\s+');

    try {
      await DBService().saveCustomRule(widget.sender, finalRegex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Regex Protocol Synthesized!",
              style: Constants.fontRegular.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Constants.colorPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Syntax Error: $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: Constants.colorError,
            behavior: SnackBarBehavior.floating,
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
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text("NEURAL PARSER TRAINING", style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            _buildSectionHeader(Icons.hub_rounded, "TOKEN EXTRACTION PROTOCOL").animate().fadeIn().slideX(),
            const SizedBox(height: 12),
            
            Text(
              "Tap the data fragments below to map the exact locations of the 'Amount' and 'Target Node'.",
              style: Constants.fontRegular.copyWith(fontSize: 13, height: 1.5, color: Colors.white70),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: Constants.glassDecoration.copyWith(
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: []
              ),
              child: Wrap(
                spacing: 10.0,
                runSpacing: 14.0,
                children: () {
                  List<Widget> chips = [];
                  for (int i = 0; i < _words.length; i++) {
                    if (_merchantIndices.contains(i)) {
                      int start = i;
                      while (i + 1 < _words.length &&
                          _merchantIndices.contains(i + 1)) {
                        i++;
                      }
                      int end = i;

                      String groupText =
                          _words.sublist(start, end + 1).join(' ');

                      chips.add(
                        GestureDetector(
                          onTap: () => _showGroupTaggingBottomSheet(start, end),
                          child: _buildTokenChip(
                            groupText,
                            Constants.colorAccent.withValues(alpha: 0.15),
                            borderColor: Constants.colorAccent,
                            textColor: Constants.colorAccent,
                            isTag: true,
                            label: "TARGET NODE",
                          ),
                        ).animate().scale(curve: Curves.elasticOut),
                      );
                    } else {
                      Color bgColor = Colors.black45;
                      Color borderColor = Colors.white10;
                      Color textColor = Colors.white60;
                      bool isAmount = i == _amountIndex;
                      String tagLabel = "";

                      if (isAmount) {
                        bgColor = Constants.colorPrimary.withValues(alpha: 0.15);
                        borderColor = Constants.colorPrimary;
                        textColor = Constants.colorPrimary;
                        tagLabel = "EXTRACTED AMT";
                      }

                      int currentIndex = i;
                      chips.add(
                        GestureDetector(
                          onTap: () => _showTaggingBottomSheet(currentIndex),
                          child: _buildTokenChip(
                            _words[currentIndex],
                            bgColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            isTag: isAmount,
                            label: tagLabel,
                          ),
                        ).animate().fade(delay: (20 * i).ms).slideY(begin: 0.1),
                      );
                    }
                  }
                  return chips;
                }(),
              ),
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
      floatingActionButton: (_amountIndex != null && _merchantIndices.isNotEmpty)
          ? FloatingActionButton.extended(
              backgroundColor: Constants.colorPrimary,
              elevation: 8,
              onPressed: _generateAndSaveRule,
              label: Text(
                "SYNTHESIZE REGEX",
                style: Constants.fontRegular.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
              icon: const Icon(Icons.memory_rounded, color: Colors.black, size: 20),
            ).animate().scale(curve: Curves.easeOutBack)
          : null,
    );
  }

  // --- UI HELPER: Cyber-Styled Token Chips ---
  Widget _buildTokenChip(
    String text, 
    Color bgColor,
    {
      required Color borderColor,
      Color textColor = Colors.white, 
      bool isTag = false, 
      String label = ""
    }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: isTag
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Constants.fontRegular.copyWith(
              color: textColor,
              fontWeight: isTag ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
              fontFamily: 'monospace', // Gives it that raw data look
            ),
          ),
          if (isTag && label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4)
              ),
              child: Text(
                label,
                style: Constants.fontRegular.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}