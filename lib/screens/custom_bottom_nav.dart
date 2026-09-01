import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'community_screen.dart';
import 'ranking_screen.dart';
import 'profile_screen.dart';

// ✅ Reusable Bottom Nav Bar - 4 tabs (เอา Activity ออก)
// ใช้ใน HomeScreen, CommunityScreen, RankingScreen, ProfileScreen
Widget buildCustomBottomNav(
  BuildContext context,
  String activeScreen, // 'home', 'community', 'ranking', 'profile'
) {
  return BottomAppBar(
    elevation: 8,
    child: SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(
            context,
            Icons.home,
            'nav_home'.tr(),
            activeScreen == 'home',
            onTap: () {
              if (activeScreen != 'home') {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          _buildNavIcon(
            context,
            Icons.people,
            'nav_community'.tr(),
            activeScreen == 'community',
            onTap: () {
              if (activeScreen != 'community') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                );
              }
            },
          ),
          _buildNavIcon(
            context,
            Icons.leaderboard,
            'nav_ranking'.tr(),
            activeScreen == 'ranking',
            onTap: () {
              if (activeScreen != 'ranking') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RankingScreen()),
                );
              }
            },
          ),
          _buildNavIcon(
            context,
            Icons.person,
            'nav_profile'.tr(),
            activeScreen == 'profile',
            onTap: () {
              if (activeScreen != 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildNavIcon(
  BuildContext context,
  IconData icon,
  String label,
  bool isActive, {
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFFD48EA1) : Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? const Color(0xFFD48EA1) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}