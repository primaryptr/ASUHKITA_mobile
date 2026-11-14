import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../features/auth/auth_provider.dart';
import '../features/communication/family_room_screen.dart';
import '../features/home/home_screen.dart';
import '../features/reports/progress_feed_screen.dart';
import '../features/sponsor/sponsor_screen.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _profileKeyCounter = 0;

  void _navigateToTab(int index, {required int profileIdx}) {
    if (index == 0) {
      HomeScreen.refreshNotifier.value++;
    } else if (index == profileIdx) {
      ProfileScreen.refreshNotifier.value++;
      _profileKeyCounter++;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.userRole == 'admin_panti';
    const int profileIdx = 4;

    final List<Widget> pages = isAdmin
        ? [
            HomeScreen(onNavigateTab: (i) => _navigateToTab(i, profileIdx: profileIdx)),
            const AdminPanelScreen(),
            const ScheduleScreen(),
            const FamilyRoomScreen(),
            ProfileScreen(key: ValueKey('profile_admin_$_profileKeyCounter')),
          ]
        : [
            HomeScreen(onNavigateTab: (i) => _navigateToTab(i, profileIdx: profileIdx)),
            const SponsorScreen(),
            const ProgressFeedScreen(),
            const FamilyRoomScreen(),
            ProfileScreen(key: ValueKey('profile_donatur_$_profileKeyCounter')),
          ];

    final List<BottomNavigationBarItem> items = isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Kelola Panti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Jadwal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'Ruang Kasih',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_outlined),
              activeIcon: Icon(Icons.volunteer_activism),
              label: 'Sponsor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.newspaper_outlined),
              activeIcon: Icon(Icons.newspaper),
              label: 'Kabar Anak',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'Ruang Kasih',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ];

    final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) {
          _navigateToTab(index, profileIdx: profileIdx);
        },
        items: items,
      ),
    );
  }
}
