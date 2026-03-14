import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';

class AppNotificationsScreen extends StatefulWidget {
  const AppNotificationsScreen({super.key});

  @override
  State<AppNotificationsScreen> createState() => _AppNotificationsScreenState();
}

class _AppNotificationsScreenState extends State<AppNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final insights = await DBService().getAppNotifications();
    setState(() {
      _notifications = insights;
      _isLoading = false;
    });
  }

  Future<void> _deleteNotification(int id) async {
    await DBService().deleteAppNotification(id);
    _loadNotifications();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Constants.colorAccent.withValues(alpha: 0.2), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 2.seconds).fade(end: 0),
              Icon(Icons.shield_outlined, size: 50, color: Constants.colorAccent.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Text("SYSTEM NOMINAL", style: Constants.headerStyle.copyWith(color: Constants.colorAccent.withValues(alpha: 0.8), letterSpacing: 4, fontSize: 14)),
          const SizedBox(height: 8),
          Text("No active anomalies or budget\nbreaches detected.", textAlign: TextAlign.center, style: Constants.subHeaderStyle.copyWith(fontSize: 11)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "INSIGHTS HUB", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.memory_rounded, size: 14, color: Constants.colorAccent),
                const SizedBox(width: 8),
                Text(
                  "SYSTEM LOGS",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Constants.colorAccent))
                : _notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24, top: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final date = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
                          
                          // Dynamic severity styling
                          String title = item['title'].toString().toLowerCase();
                          Color glowColor = Constants.colorAccent; // Default AI Purple
                          IconData alertIcon = Icons.auto_awesome_rounded;
                          
                          if (title.contains("breach") || title.contains("exceed")) {
                            glowColor = Constants.colorError;
                            alertIcon = Icons.warning_amber_rounded;
                          } else if (title.contains("warning") || title.contains("approaching")) {
                            glowColor = Colors.orangeAccent;
                            alertIcon = Icons.trending_up_rounded;
                          } else if (title.contains("top spend")) {
                            glowColor = Colors.lightBlueAccent;
                            alertIcon = Icons.pie_chart_outline_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Dismissible(
                              key: Key(item['id'].toString()),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
  _deleteNotification(item['id']);
  
  // Clear old snackbars first
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text("Log expunged", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Constants.colorAccent,
      duration: const Duration(seconds: 2), // Improved duration
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
},
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Constants.colorError.withValues(alpha: 0.5), width: 1.5),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Constants.colorError.withValues(alpha: 0.05),
                                      Constants.colorError.withValues(alpha: 0.25),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text("EXPUNGE", 
                                      style: TextStyle(
                                        color: Constants.colorError, 
                                        fontWeight: FontWeight.w900, 
                                        letterSpacing: 3, 
                                        fontSize: 12,
                                        shadows: [Shadow(color: Constants.colorError.withValues(alpha: 0.5), blurRadius: 4)]
                                      )
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.delete_sweep_rounded, color: Constants.colorError, size: 24),
                                  ],
                                ),
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
                                      glowColor.withValues(alpha: 0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Glowing Edge
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: glowColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: glowColor.withValues(alpha: 0.8),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Icon
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: glowColor.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: glowColor.withValues(alpha: 0.3), width: 1),
                                        ),
                                        child: Icon(alertIcon, color: glowColor, size: 20),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Text Body
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item['title'].toString().toUpperCase(),
                                                style: TextStyle(
                                                  color: glowColor, 
                                                  fontWeight: FontWeight.w800, 
                                                  fontSize: 11, 
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item['body'], 
                                                style: const TextStyle(
                                                  color: Colors.white, 
                                                  fontSize: 13, 
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w500
                                                )
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.3), size: 10),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat('MMM dd, hh:mm a').format(date),
                                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}