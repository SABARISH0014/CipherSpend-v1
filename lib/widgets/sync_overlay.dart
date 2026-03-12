import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SyncOverlay extends StatelessWidget {
  final int total;
  final int current;
  final String status;

  const SyncOverlay({
    super.key,
    required this.total,
    required this.current,
    this.status = "Analyzing Financial History...",
  });

  @override
  Widget build(BuildContext context) {
    double progress = total > 0 ? (current / total) : 0;

    return Container(
      color: Colors.black87, // Dim the background
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: Constants.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Constants.colorPrimary),
              const SizedBox(height: 24),
              Text(
                status,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Processed $current of $total messages",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black26,
                color: Constants.colorPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(
                    color: Constants.colorPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic).fade(duration: 300.ms),
      ),
    );
  }
}
