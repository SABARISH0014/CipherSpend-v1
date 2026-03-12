import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class VisualReportScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final double budget;

  const VisualReportScreen(
      {super.key, required this.transactions, required this.budget});

  @override
  State<VisualReportScreen> createState() => _VisualReportScreenState();
}

class _VisualReportScreenState extends State<VisualReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Speed of the flow
    )..repeat(); // Loop indefinitely
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            const Text("SANKEY FLOW CHART", style: Constants.headerStyle),
            const SizedBox(height: 5),
            const Text("Budget → Categories", style: Constants.subHeaderStyle),
            const SizedBox(height: 30),

            // THE CHART CANVAS
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 400),
                    painter: SankeyPainter(
                      budget: widget.budget,
                      totalSpent: totalSpent,
                      categories: sortedEntries,
                      animationValue: _controller.value,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // LEGEND
            ...sortedEntries
                .map((e) => _buildLegendItem(e.key, e.value, totalSpent)),
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
  final double animationValue;

  SankeyPainter(
      {required this.budget,
      required this.totalSpent,
      required this.categories,
      required this.animationValue});

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
      Color categoryColor = _getColor(entry.key);
      paint.color = categoryColor;
      
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

      // Background stream
      Paint flowPaint = Paint()
        ..color = categoryColor.withOpacity(0.2) // Lighter background
        ..style = PaintingStyle.stroke
        ..strokeWidth = catHeight * 0.8 // Thickness based on amount
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, flowPaint);

      // --- ANIMATED PARTICLES STREAM ---
      // We extract metrics to draw glowing "data segments" moving along the path.
      if (path.computeMetrics().isNotEmpty) {
        ui.PathMetrics pathMetrics = path.computeMetrics();
        ui.PathMetric metric = pathMetrics.first;
        
        double pathLength = metric.length;
        
        // Define animation parameters
        int numParticles = 3; // Number of particles flowing on this path
        double dashLength = pathLength * 0.15; // Length of each glowing dash
        
        Paint particlePaint = Paint()
          ..color = categoryColor.withOpacity(0.8) // Brighter for flowing data
          ..style = PaintingStyle.stroke
          ..strokeWidth = catHeight * 0.6 // Slightly thinner than bg stream
          ..strokeCap = StrokeCap.round;
          
        for (int i = 0; i < numParticles; i++) {
            // Offset logic for staggered looping particles
            double phaseOffset = i / numParticles; 
            double currentProgress = (animationValue + phaseOffset) % 1.0;
            
            double startDistance = (pathLength + dashLength) * currentProgress - dashLength;
            double endDistance = startDistance + dashLength;
            
            // Extract the moving path segment
            ui.Path extractPath = metric.extractPath(
                startDistance.clamp(0.0, pathLength), 
                endDistance.clamp(0.0, pathLength)
            );
            
            canvas.drawPath(extractPath, particlePaint);
        }
      }

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
  bool shouldRepaint(covariant SankeyPainter oldDelegate) {
     return oldDelegate.animationValue != animationValue || 
            oldDelegate.budget != budget ||
            oldDelegate.totalSpent != totalSpent;
  }
}
