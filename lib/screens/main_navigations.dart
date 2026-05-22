import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'info_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainNavigation
//
// Shell utama aplikasi. Menyimpan PageController sehingga setiap layar
// bisa memanggil _goToTab(index) untuk navigasi antar tab.
//
// Index tab:  0=Home  1=Scan  2=History  3=Info  4=Profile
// ─────────────────────────────────────────────────────────────────────────────

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // swipe disabled — use tabs only
        children: [
          // ── Tab 0: Home / Dashboard ─────────────────────────────────────
          DashboardScreen(
            onGoToScanner: () => _goToTab(1),
            onGoToHistory: () => _goToTab(2),
          ),

          // ── Tab 1: Scanner ──────────────────────────────────────────────
          const ScannerScreen(),

          // ── Tab 2: History ──────────────────────────────────────────────
          const HistoryScreen(),

          // ── Tab 3: Info ─────────────────────────────────────────────────
          const InfoScreen(),

          // ── Tab 4: Profile / Settings ───────────────────────────────────
          SettingsScreen(
            onGoToScanner: () => _goToTab(1),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _goToTab,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.camera_alt_rounded, label: 'Scan'),
      _NavItem(icon: Icons.history_rounded, label: 'History'),
      _NavItem(icon: Icons.info_outline_rounded, label: 'Info'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    items[i].icon,
                    color: active ? const Color(0xFF00C896) : const Color(0xFF4A5568),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].label,
                    style: TextStyle(
                      color: active ? const Color(0xFF00C896) : const Color(0xFF4A5568),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}