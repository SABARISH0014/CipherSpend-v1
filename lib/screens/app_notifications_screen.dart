import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Insights Hub"),
        backgroundColor: Constants.colorSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read, size: 80, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        "You're all caught up!",
                        style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "AI-generated insights and budget alerts will appear here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);

                    return Dismissible(
                      key: Key(item['id'].toString()),
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) {
                        _deleteNotification(item['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Insight dismissed"),
                            backgroundColor: Constants.colorPrimary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      background: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerRight,
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        color: Constants.colorSurface,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Constants.colorPrimary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: Constants.colorPrimary),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item['body'], style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('MMM dd, hh:mm a').format(date),
                                style: const TextStyle(color: Colors.white30, fontSize: 10),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
