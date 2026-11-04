import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/encourise_theme.dart';
import 'home_screen.dart';
import 'free_chat_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';

/// Kelas Tenang app shell with a calm bottom navigation bar.
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  int _notesRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(isTab: true),
      const FreeChatScreen(grade: 0, isTab: true),
      NotesScreen(isTab: true, refreshToken: _notesRefreshToken),
      const SettingsScreen(isTab: true),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: EncouriseColors.navBarBg,
        boxShadow: EncouriseShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Beranda',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Tanya',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.sticky_note_2_outlined,
                activeIcon: Icons.sticky_note_2_rounded,
                label: 'Catatan',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 2) _notesRefreshToken++;
      }),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? EncouriseColors.primarySurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(EncouriseRadius.pill),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive
                    ? EncouriseColors.navActive
                    : EncouriseColors.navInactive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? EncouriseColors.navActive
                    : EncouriseColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
