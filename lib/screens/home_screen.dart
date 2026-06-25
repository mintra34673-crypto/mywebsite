import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_screen.dart';
import 'bin_location_screen.dart';
import 'rewards_screen.dart';
import 'waste_guide_screen.dart';
import 'scan_waste_screen.dart';
import 'my_qr_code_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final String currentLang = context.locale.languageCode;
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      key: ValueKey(currentLang),
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'home'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildImageBanner(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int myPoints = 0;
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Center(
                            child: Text("Error loading data",
                                style: TextStyle(color: Colors.red)),
                          ),
                        );
                      }
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFD48EA1)),
                          ),
                        );
                      }
                      if (snapshot.hasData &&
                          snapshot.data!.exists &&
                          snapshot.data!.data() != null) {
                        var userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        myPoints = userData['points'] ?? 0;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 25),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E3),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE4E1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars_rounded,
                                  color: Color(0xFFD48EA1), size: 35),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('your_points'.tr(),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                  "${NumberFormat('#,###').format(myPoints)} ${'points'.tr()}",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF81C784),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.1,
                    children: [
                      _buildMenuCard(context, 'scan_waste'.tr(),
                          Icons.camera_alt_outlined, const Color(0xFFFFF9E3),
                          const ScanWasteScreen()),
                      _buildMenuCard(context, 'waste_guide'.tr(),
                          Icons.auto_stories_outlined,
                          const Color(0xFFFFF9E3), const WasteGuideScreen()),
                      _buildMenuCard(context, 'bin_location'.tr(),
                          Icons.location_on_outlined,
                          const Color(0xFFFFF9E3), const BinLocationScreen()),
                      _buildMenuCard(context, 'rewards'.tr(),
                          Icons.emoji_events_outlined,
                          const Color(0xFFFFF9E3), const RewardsScreen()),
                    ],
                  ),
                ),
                // เผื่อพื้นที่ด้านล่างไม่ให้ปุ่ม chatbot วงกลมทับเนื้อหา
                const SizedBox(height: 90),
              ],
            ),
          ),
          // ✅ ปุ่ม chatbot วงกลม ฝั่งขวามือ -> ไปหน้า EcoBot (Gemini)
          Positioned(
            right: 20,
            bottom: 100,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E6C9),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFA5D6A7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: Colors.green, size: 30),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(context, Icons.home_filled, 'home', true),
              _buildNavIcon(context, Icons.grid_view_rounded, 'activity', false,
                  const ActivityScreen()),
              const SizedBox(width: 45),
              _buildNavIcon(context, Icons.leaderboard_outlined, 'ranking',
                  false, const RankingScreen()),
              _buildNavIcon(context, Icons.person_outline_rounded, 'profile',
                  false, const ProfileScreen()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4B996),
        elevation: 4,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyQrCodeScreen())),
        child: const Icon(Icons.qr_code_scanner_rounded,
            color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildImageBanner() {
    final List<Map<String, dynamic>> banners = [
      {
        "imagePath": "assets/images/banner2.png",
        "overlayColor": const Color(0xFF1B5E20),
        "icon": Icons.delete_outline_rounded,
        "title": "ขยะล้นเมือง คนไทยสร้าง 7.3 หมื่นตัน/วัน",
        "subtitle": "สถานการณ์ขยะไทยปี 2566 และแนวทางแก้ไข",
        "url": "https://www.thaipbs.or.th/news/content/340722",
      },
      {
        "imagePath": "assets/images/banner1.png",
        "overlayColor": const Color(0xFF006064),
        "icon": Icons.recycling,
        "title": "ตู้แลกขยะ รับพลาสติก-อะลูมิเนียม",
        "subtitle": "Drop It. Transform It. Change the Future.",
        "url": "https://theactive.thaipbs.or.th/news/pollution-20251122",
      },
      {
        "imagePath": "assets/images/banner3.png",
        "overlayColor": const Color(0xFF0D47A1),
        "icon": Icons.gavel_rounded,
        "title": "ดัน พ.ร.บ.เศรษฐกิจหมุนเวียน แก้วิกฤตขยะไทย",
        "subtitle": "ขยะ 27 ล้านตัน/ปี กับทางออกระยะยาวของประเทศ",
        "url": "https://www.sdgmove.com/2026/05/19/thailand-circular-economy-law-waste-crisis/",
      },
    ];

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return GestureDetector(
            onTap: () async {
              final Uri url = Uri.parse(banner['url'] as String);
              if (!await launchUrl(url,
                  mode: LaunchMode.externalApplication)) {
                throw 'Could not launch $url';
              }
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (banner['overlayColor'] as Color).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      banner['imagePath'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: (banner['overlayColor'] as Color),
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 48),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            (banner['overlayColor'] as Color).withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(banner['icon'] as IconData,
                              color: Colors.white, size: 36),
                          const SizedBox(height: 10),
                          Text(
                            banner['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    blurRadius: 6,
                                    color: Colors.black54,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner['subtitle'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon,
      Color color, Widget nextScreen) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => nextScreen)),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: const Color(0xFFD4B996)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ✅ แก้แล้ว: ใช้ nextScreen ที่ส่งมาจริงๆ แทน hardcode ScanWasteScreen
  Widget _buildNavIcon(BuildContext context, IconData icon, String langKey,
      bool isActive, [Widget? nextScreen]) {
    return GestureDetector(
      onTap: () {
        if (nextScreen != null && !isActive) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => nextScreen));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? const Color(0xFFD48EA1) : Colors.grey,
              size: 26),
          const SizedBox(height: 2),
          Text(langKey.tr(),
              style: TextStyle(
                  fontSize: 11,
                  color: isActive ? const Color(0xFFD48EA1) : Colors.grey,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
