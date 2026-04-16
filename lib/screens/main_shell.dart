import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // Home is default (middle)

  final List<Widget> _screens = const [
    ReportScreen(),
    HomeScreen(),
    SettingsScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: context.appTextHint,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  activeIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Report',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
          // Banner ad sits below the nav bar on all tabs
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

