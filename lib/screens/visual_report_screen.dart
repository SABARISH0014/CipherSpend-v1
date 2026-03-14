import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
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

    var sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, // Prevents scroll color-shift
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "FLOW ANALYSIS", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_rounded, size: 14, color: Constants.colorAccent),
                  const SizedBox(width: 8),
                  Text(
                    "SANKEY NETWORK",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().fadeIn().slideX(begin: -0.1),
            ),
            const SizedBox(height: 16),

            // THE CHART CANVAS WRAPPED IN GLASSMORPHISM
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: Constants.glassDecoration.copyWith(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(MediaQuery.of(context).size.width * 0.8, 350),
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
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),

            const SizedBox(height: 32),

            // LEGEND HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.data_usage_rounded, size: 14, color: Constants.colorPrimary),
                  const SizedBox(width: 8),
                  Text(
                    "SPEND BREAKDOWN",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),
            ),
            const SizedBox(height: 16),
            
            // DYNAMIC LEDGER ITEMS
            ...sortedEntries.asMap().entries.map((mapEntry) {
              int index = mapEntry.key;
              var entry = mapEntry.value;
              return _buildLegendItem(entry.key, entry.value, totalSpent)
                  .animate()
                  .fade(duration: 400.ms, delay: (400 + (50 * index)).ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic);
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UPGRADED CYBER-NODE LEGEND ITEM ---
  Widget _buildLegendItem(String cat, double amount, double total) {
    double percent = total > 0 ? (amount / total * 100) : 0.0;
    final catColor = _getColor(cat);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.03),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Constants.colorSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              catColor.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Glowing Neon Strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: catColor,
                  boxShadow: [
                    BoxShadow(
                      color: catColor.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                ),
              ),
              const SizedBox(width: 16),
              
              // Category Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: catColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(Icons.circle, color: catColor, size: 12),
              ),
              const SizedBox(width: 16),
              
              // Category Name
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    cat.toUpperCase(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                  ),
                ),
              ),
              
              // Percent Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Text(
                  "${percent.toStringAsFixed(1)}%",
                  style: Constants.fontRegular.copyWith(fontSize: 11, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 12),
              
              // Amount
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  "₹${amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.greenAccent;
    if (lowerCat.contains('travel')) return Colors.lightBlueAccent;
    if (lowerCat.contains('shopping')) return Colors.amberAccent;
    if (lowerCat.contains('bills')) return Colors.redAccent;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orangeAccent;
    if (lowerCat.contains('investment')) return Constants.colorAccent;
    if (lowerCat.contains('transaction')) return Colors.indigoAccent;
    return Colors.grey;
  }
}

// --- UPGRADED GLOWING PAINTER ---
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
    double leftX = 10;
    double rightX = size.width - 10;
    double barWidth = 16;
    double totalHeight = size.height * 0.9;
    double startY = (size.height - totalHeight) / 2;

    // Budget Source Node (Glowing)
    paint.color = Constants.colorPrimary;
    paint.maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 4); // Added soft glow
    Rect leftRect = Rect.fromLTWH(leftX, startY, barWidth, totalHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(8)), paint);
    paint.maskFilter = null; // Reset for other paths

    double currentY = startY;

    for (var entry in categories) {
      double proportion = entry.value / (totalSpent > 0 ? totalSpent : 1);
      double catHeight = totalHeight * proportion;
      if (catHeight < 4) catHeight = 4;

      Color categoryColor = _getColor(entry.key);
      
      // Category Target Node
      paint.color = categoryColor;
      Rect rightRect = Rect.fromLTWH(rightX, currentY, barWidth, catHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(8)), paint);

      // Flow Path
      Path path = Path();
      path.moveTo(leftX + barWidth, startY + (totalHeight / 2));
      path.cubicTo(
          leftX + size.width * 0.5, startY + (totalHeight / 2),
          rightX - size.width * 0.5, currentY + (catHeight / 2),
          rightX, currentY + (catHeight / 2));

      // Dim Background Flow
      Paint flowPaint = Paint()
        ..color = categoryColor.withValues(alpha: 0.1) 
        ..style = PaintingStyle.stroke
        ..strokeWidth = catHeight * 0.7 
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, flowPaint);

      // Animated Glowing Particles
      if (path.computeMetrics().isNotEmpty) {
        ui.PathMetrics pathMetrics = path.computeMetrics();
        ui.PathMetric metric = pathMetrics.first;
        double pathLength = metric.length;
        int numParticles = 3; 
        double dashLength = pathLength * 0.15; 
        
        Paint particlePaint = Paint()
          ..color = categoryColor.withValues(alpha: 0.9) 
          ..style = PaintingStyle.stroke
          ..strokeWidth = catHeight * 0.3 
          ..strokeCap = StrokeCap.round
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 6); // Laser glow effect
          
        for (int i = 0; i < numParticles; i++) {
            double phaseOffset = i / numParticles; 
            double currentProgress = (animationValue + phaseOffset) % 1.0;
            double startDistance = (pathLength + dashLength) * currentProgress - dashLength;
            double endDistance = startDistance + dashLength;
            ui.Path extractPath = metric.extractPath(startDistance.clamp(0.0, pathLength), endDistance.clamp(0.0, pathLength));
            canvas.drawPath(extractPath, particlePaint);
        }
      }
      currentY += catHeight + 8; 
    }
  }

  Color _getColor(String cat) {
    String lowerCat = cat.toLowerCase();
    if (lowerCat.contains('food')) return Colors.greenAccent;
    if (lowerCat.contains('travel')) return Colors.lightBlueAccent;
    if (lowerCat.contains('shopping')) return Colors.amberAccent;
    if (lowerCat.contains('bills')) return Colors.redAccent;
    if (lowerCat.contains('refund')) return Colors.tealAccent;
    if (lowerCat.contains('cash')) return Colors.orangeAccent;
    if (lowerCat.contains('investment')) return Constants.colorAccent;
    if (lowerCat.contains('transaction')) return Colors.indigoAccent;
    return Colors.grey;
  }

  @override
  bool shouldRepaint(covariant SankeyPainter oldDelegate) {
     return oldDelegate.animationValue != animationValue || 
            oldDelegate.budget != budget ||
            oldDelegate.totalSpent != totalSpent;
  }
}