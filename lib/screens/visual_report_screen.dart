import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VisualReportScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final double budget;

  const VisualReportScreen(
      {super.key, required this.transactions, required this.budget});

  @override
  State<VisualReportScreen> createState() => _VisualReportScreenState();
}

class _VisualReportScreenState extends State<VisualReportScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Group Data by Category
    Map<String, double> categoryTotals = {};
    double totalSpent = 0;

    for (var txn in widget.transactions) {
      categoryTotals[txn.category] =
          (categoryTotals[txn.category] ?? 0) + txn.amount;
      totalSpent += txn.amount;
    }

    // Sort categories by spend (highest first)
    var sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Money Flow Analysis"),
        backgroundColor: Constants.colorSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SANKEY FLOW CHART", style: Constants.headerStyle),
            const SizedBox(height: 5),
            Text("Budget → Categories", style: Constants.subHeaderStyle),
            const SizedBox(height: 30),

            // THE CHART CANVAS
            Center(
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 400),
                painter: SankeyPainter(
                  budget: widget.budget,
                  totalSpent: totalSpent,
                  categories: sortedEntries,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // LEGEND
            ...sortedEntries
                .asMap()
                .map((index, e) => MapEntry(
                      index,
                      _buildLegendItem(e.key, e.value, totalSpent)
                          .animate()
                          .fade(delay: (100 * index).ms)
                          .slideX(begin: 0.1, curve: Curves.easeOutCubic),
                    ))
                .values,
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String cat, double amount, double total) {
    double percent = (amount / total * 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: _getColor(cat)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(cat, style: const TextStyle(color: Colors.white))),
          Text("₹${amount.toStringAsFixed(0)}",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text("${percent.toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // --- UPDATED COLOR MAPPING ---
  Color _getColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.green;
    if (lowerCat.contains('travel')) return Colors.blue;
    if (lowerCat.contains('shopping')) return Colors.amber;
    if (lowerCat.contains('bills')) return Colors.red;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orange;
    if (lowerCat.contains('investment')) return Colors.purpleAccent;
    if (lowerCat.contains('transaction')) return Colors.indigo;

    // Kept for backward compatibility with old DB records
    if (lowerCat.contains('entertainment')) return Colors.purple;
    if (lowerCat.contains('grocery')) return Colors.teal;

    return Colors.grey;
  }
}

// --- THE PAINTER LOGIC ---
class SankeyPainter extends CustomPainter {
  final double budget;
  final double totalSpent;
  final List<MapEntry<String, double>> categories;

  SankeyPainter(
      {required this.budget,
      required this.totalSpent,
      required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Config
    double leftX = 20;
    double rightX = size.width - 20;
    double barWidth = 20;

    // 1. Draw LEFT Bar (Total Budget or Spent)
    // We base height on Total Spent to fill the view nicely
    double totalHeight = size.height * 0.8;
    double startY = (size.height - totalHeight) / 2;

    paint.color = Constants.colorPrimary;
    Rect leftRect = Rect.fromLTWH(leftX, startY, barWidth, totalHeight);
    canvas.drawRRect(
        RRect.fromRectAndRadius(leftRect, const Radius.circular(4)), paint);

    // 2. Draw RIGHT Bars (Categories) & Curves
    double currentY = startY;

    for (var entry in categories) {
      // Calculate relative height for this category
      double proportion = entry.value / totalSpent;
      double catHeight = totalHeight * proportion;

      // Safety gap
      if (catHeight < 2) catHeight = 2;

      // Draw Right Bar
      paint.color = _getColor(entry.key);
      Rect rightRect = Rect.fromLTWH(rightX, currentY, barWidth, catHeight);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rightRect, const Radius.circular(4)), paint);

      // Draw Connection Curve (The Sankey Stream)
      Path path = Path();
      path.moveTo(leftX + barWidth,
          startY + (totalHeight / 2)); // Start from center of left
      path.cubicTo(
          leftX + size.width * 0.5,
          startY + (totalHeight / 2), // Control point 1
          rightX - size.width * 0.5,
          currentY + (catHeight / 2), // Control point 2
          rightX,
          currentY + (catHeight / 2) // End at center of right node
          );

      // Stroke style for the stream
      Paint flowPaint = Paint()
        ..color = _getColor(entry.key).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = catHeight * 0.8 // Thickness based on amount
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, flowPaint);

      currentY += catHeight + 5; // Add small gap
    }
  }

  // --- UPDATED COLOR MAPPING FOR PAINTER ---
  Color _getColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.green;
    if (lowerCat.contains('travel')) return Colors.blue;
    if (lowerCat.contains('shopping')) return Colors.amber;
    if (lowerCat.contains('bills')) return Colors.red;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orange;
    if (lowerCat.contains('investment')) return Colors.purpleAccent;
    if (lowerCat.contains('transaction')) return Colors.indigo;

    // Kept for backward compatibility with old DB records
    if (lowerCat.contains('entertainment')) return Colors.purple;
    if (lowerCat.contains('grocery')) return Colors.teal;

    return Colors.grey;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
