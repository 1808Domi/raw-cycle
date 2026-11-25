import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../statistics/presentation/statistics_page.dart';
import 'placeholder_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const _pages = [
    PageDetails(
      title: 'Übersicht',
      description: 'Hier entsteht deine persönliche Zyklusübersicht.',
      icon: Icons.favorite_rounded,
      accentColor: AppTheme.lavender,
    ),
    PageDetails(
      title: 'Kalender',
      description: 'Dein Zykluskalender wird hier bald angezeigt.',
      icon: Icons.calendar_month_rounded,
      accentColor: Color(0xFFCC829A),
    ),
    PageDetails(
      title: 'Statistik',
      description: 'Hier findest du bald spannende Einblicke in deinen Zyklus.',
      icon: Icons.insights_rounded,
      accentColor: Color(0xFF6D9E8B),
    ),
    PageDetails(
      title: 'Einstellungen',
      description: 'Passe Raw Cycle ganz nach deinen Wünschen an.',
      icon: Icons.tune_rounded,
      accentColor: AppTheme.lavender,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          page.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _selectedIndex == 0
          ? const DashboardPage()
          : _selectedIndex == 1
          ? const CalendarPage()
          : _selectedIndex == 2
          ? const StatisticsPage()
          : _selectedIndex == 3
          ? const SettingsPage()
          : PlaceholderPage(details: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Übersicht',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}

class PageDetails {
  const PageDetails({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
}
