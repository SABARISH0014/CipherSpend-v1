import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/sms_service.dart';
import '../widgets/sync_overlay.dart';

import 'dashboard_screen.dart';
import 'visual_report_screen.dart';
import 'manual_entry_screen.dart';
import 'search_export_screen.dart';
import 'settings_screen.dart';

class MainWrapperScreen extends StatefulWidget {
  const MainWrapperScreen({super.key});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  int _currentIndex = 0;

// Removed static _screens to dynamically build it with _isSyncing state

  bool _isSyncing = false;
  int _totalToSync = 0;
  int _currentSynced = 0;
  int _refreshCounter = 0; // Triggers UI refresh when manual records are generated

  @override
  void initState() {
    super.initState();
    _checkAndRunInitialSync();
  }

  Future<void> _checkAndRunInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSynced = prefs.getBool('has_initial_sync_completed') ?? false;

    if (!hasSynced) {
      setState(() => _isSyncing = true);

      await SmsService().syncHistory(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentSynced = current;
              _totalToSync = total;
            });
          }
        },
      );

      await prefs.setBool('has_initial_sync_completed', true);
      
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        isGlobalSyncing: _isSyncing, 
        refreshTrigger: _refreshCounter,
      ),
      VisualReportScreen(
        isGlobalSyncing: _isSyncing, 
        refreshTrigger: _refreshCounter,
        onReturnToDashboard: () => _onTabTapped(0),
      ),
      SearchExportScreen(
        isGlobalSyncing: _isSyncing, 
        refreshTrigger: _refreshCounter,
        onReturnToDashboard: () => _onTabTapped(0),
      ),
      SettingsScreen(
        onReturnToDashboard: () => _onTabTapped(0),
      ),
    ];

    return AbsorbPointer(
      absorbing: _isSyncing,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Constants.colorBackground,
            extendBody: true,
      
            body: IndexedStack(index: _currentIndex, children: screens),
      
            bottomNavigationBar: Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 24,
                top: 12,
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
              child:
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      // MATCHED: Using your standard glass blur from the Smart Prompt
                      filter: Constants.glassBlur,
                      child: Container(
                        height: 72,
                        // MATCHED: Merging your dialog's glassDecoration with the dock's pill shape
                        decoration: Constants.glassDecoration.copyWith(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(0, Icons.dashboard_rounded, "Ledger"),
                            _buildNavItem(1, Icons.bar_chart_rounded, "Analytics"),
      
                            _buildCenterFab(),
      
                            _buildNavItem(2, Icons.search_rounded, "Vault"),
                            _buildNavItem(3, Icons.settings_rounded, "System"),
                          ],
                        ),
                      ),
                    ),
                  ).animate().slideY(
                    begin: 1.0,
                    curve: Curves.easeOutCubic,
                    duration: 800.ms,
                  ),
            ),
          ),
          
          if (_isSyncing)
            Positioned.fill(
              child: SyncOverlay(
                total: _totalToSync,
                current: _currentSynced,
                status: "Importing Financial History...",
              ).animate().fadeIn(duration: 400.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    Color color = isSelected ? Constants.colorPrimary : Colors.white54;

    // 1. Wrap the entire item in an Expanded widget
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 2. Remove horizontal padding so Expanded can fluidly manage the width
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
                child: Icon(
                  icon,
                  color: color,
                  size: isSelected ? 26 : 22,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ]
                      : [],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: isSelected
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            label,
                            maxLines:
                                1, // Ensures text shrinks gracefully on tiny screens
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing:
                                  0.5, // Slightly reduced to prevent text clipping
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 3,
                            width: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    // 3. Remove the hardcoded width: 48. Expanded handles the tap target area now!
                    : const SizedBox(height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFab() {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.heavyImpact(),
      onTapUp: (_) async {
        bool? added = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
        );
        if (added == true && mounted) {
          setState(() => _refreshCounter++);
        }
      },
      child:
          Container(
                height: 56,
                width: 56,
                margin: const EdgeInsets.only(top: 0), // Removed bottom margin to level with other buttons
                decoration: BoxDecoration(
                  color: Constants.colorSurface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Constants.colorPrimary.withValues(alpha: 0.8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    // MATCHED: Tuned to match the primary button glow from the Smart Prompt
                    BoxShadow(
                      color: Constants.colorPrimary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: Constants.colorPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Constants.colorPrimary,
                      size: 28,
                    ),
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
    );
  }
}
