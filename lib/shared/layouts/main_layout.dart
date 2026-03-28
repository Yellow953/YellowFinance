import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/nav_bar.dart';
import '../../routes/app_routes.dart';

/// Shell layout with bottom navigation. Manages tab switching.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<String> _routes = [
    AppRoutes.HOME,
    AppRoutes.TRANSACTIONS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
    AppRoutes.AI_CHAT,
  ];

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    Get.offAllNamed(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Get.routing.current == AppRoutes.HOME
          ? const SizedBox.shrink()
          : null,
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
