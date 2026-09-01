// lib/screens/home_screen.dart - AUTO-SLIDE BANNER CAROUSEL + URL LINK
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'scan_waste_screen.dart';
import 'community_screen.dart';
import 'ranking_screen.dart';
import 'profile_screen.dart';
import 'bin_location_screen.dart';
import 'rewards_screen.dart';
import 'chatbot_screen.dart';
import 'waste_guide_screen.dart';
import 'countryside_painter.dart';
import 'app_theme.dart';

class AppColors {
  static const Color primary = Color(0xFF2D8E6F);
  static const Color primaryLight = Color(0xFF52C77E);
  static const Color primaryDark = Color(0xFF1B5E48);
  static const Color accent = Color(0xFF7FD8B8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1A1A);
  static const Color grey = Color(0xFF6C757D);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color bgLight = Color(0xFFF1F8F5);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
}

// ============================================================
// 📌 แก้ข้อมูลแบนเนอร์ตรงนี้ (รูป / หัวข้อ / คำอธิบาย / ลิงก์เว็บ)
// ============================================================
class BannerItem {
  final String imageUrl;   // URL รูปพื้นหลัง
  final IconData icon;     // ไอคอนมุมบน
  final String title;      // หัวข้อ
  final String subtitle;   // คำอธิบาย
  final String link;       // ลิงก์เว็บที่จะเปิดเมื่อกด

  const BannerItem({
    required this.imageUrl,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.link,
  });
}
final List<BannerItem> kBanners = [
  BannerItem(
    imageUrl: 'https://images.unsplash.com/photo-1627641989483-3b7df84a786b?w=800&h=400&fit=crop&auto=format&q=80',
    icon: Icons.delete_outline,
    title: 'พลาสติกในครัวเรือนที่อันตรายที่สุด วิธีใช้ชีวิตโดยปราศจากพวกเขา',
    subtitle: 'FriendsoftheEarth',
    link: 'https://friendsoftheearth.uk/sustainable-living/worst-household-plastics-how-live-without-them',
  ),
  BannerItem(
    imageUrl: 'https://images.unsplash.com/photo-1558770147-68c0607adb26?w=800&h=400&fit=crop&auto=format&q=80',
    icon: Icons.recycling,
    title: 'Plastic Free July แคมเปญชวนลดใช้พลาสติก เริ่มโดยหญิงคนเดียว สู่ผู้รวมทะลุร้อยล้านคน',
    subtitle: 'thepeople',
    link: 'https://www.thepeople.co/environment/green-people/51925',
  ),
  BannerItem(
    imageUrl: 'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?w=800&h=400&fit=crop&auto=format&q=80',
    icon: Icons.eco,
    title: 'วิธีการจัดการขยะสำหรับชุมชน',
    subtitle: 'Greenerbangkok',
    link: 'https://greener.bangkok.go.th/welcome/',
  ),
];
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ✅ ตัวควบคุม carousel
  final PageController _bannerController = PageController(viewportFraction: 0.9);
  int _bannerIndex = 0;
  bool _userDragging = false;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // ✅ เลื่อนอัตโนมัติทุก 4 วินาที
  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_bannerController.hasClients) return;
      if (_userDragging) return; // ✅ หยุด auto ตอนผู้ใช้ลาก
      int next = _bannerIndex + 1;
      if (next >= kBanners.length) next = 0;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // ✅ เปิดลิงก์เว็บ
  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: userId != null
          ? FirebaseFirestore.instance.collection('users').doc(userId).snapshots()
          : const Stream.empty(),
      builder: (context, userSnap) {
        int userPoints = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          userPoints = (userData['points'] as num?)?.toInt() ?? 0;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(userPoints),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F4FB),
                  Color(0xFFEAF6E9),
                  Color(0xFFDCF0D5),
                ],
              ),
            ),
            child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildBannerCarousel(),   // ✅ แถบรูปเลื่อนอัตโนมัติ (แทน 3 การ์ด)
                const SizedBox(height: 8),
                _buildDotsIndicator(),
                const SizedBox(height: 6),
                _buildPointsCard(userPoints),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('home_features'.tr(),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _buildFeatureGrid(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ✅ บ้านต้นไม้ในป่า (ย้ายไปไฟล์ countryside_painter.dart แล้ว)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: CustomPaint(painter: CountrysideScenePainter()),
                ),
              ],
            ),
          ),
          ),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _buildDraggableFAB(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(int userPoints) {
  return AppBar(
    centerTitle: true, // 👈 เพิ่มบรรทัดนี้เพื่อบังคับให้อยู่ตรงกลางหน้าจอ
    title: Row(
      mainAxisSize: MainAxisSize.min, // 👈 บังคับให้ Row ขนาดพอดีกับเนื้อหาข้างใน
      children: const [
        Icon(Icons.eco, size: 24),
        SizedBox(width: 8),
        Text('BinSort', style: TextStyle(fontSize: 20, fontFamily: 'Kanit')),
      ],
    ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text('$userPoints',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Carousel แบนเนอร์รูปภาพ
  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 155,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notif) {
          if (notif is ScrollStartNotification) {
            _userDragging = true;
          } else if (notif is ScrollEndNotification) {
            // หน่วงนิดให้ animation จบก่อนเปิด auto อีกครั้ง
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _userDragging = false;
            });
          }
          return false;
        },
        child: ScrollConfiguration(
          behavior: MouseDragScrollBehavior(),
          child: PageView.builder(
        controller: _bannerController,
        physics: const BouncingScrollPhysics(), // ✅ ลากได้ลื่น
        itemCount: kBanners.length,
        onPageChanged: (i) => setState(() => _bannerIndex = i),
        itemBuilder: (context, index) {
          final banner = kBanners[index];
          return GestureDetector(
            onTap: () => _openLink(banner.link),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // รูปพื้นหลัง
                    Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppColors.bgLight,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.primary,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.white, size: 40),
                      ),
                    ),
                    // เงาดำทับให้อ่านข้อความง่าย
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                    // เนื้อหา
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(banner.icon, color: Colors.white, size: 28),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Kanit',
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                banner.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ],
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
        ),
      ),
    );
  }

  // ✅ จุดบอกตำแหน่ง carousel
  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kBanners.length, (i) {
        final isActive = i == _bannerIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ✅ การ์ดแต้มสะสม
  Widget _buildPointsCard(int userPoints) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // ✅ เขียวไล่เฉด (แบบการ์ดอันดับ 1 ใน Ranking)
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF52C77E),
            Color(0xFF2D8E6F),
            Color(0xFF1B5E48),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D8E6F).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ใบไม้จางมุมขวา
          Positioned(
            right: -8, top: -10,
            child: Icon(Icons.eco, size: 70, color: Colors.white.withOpacity(0.15)),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('your_points'.tr(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontFamily: 'Kanit')),
                  const SizedBox(height: 2),
                  Text('$userPoints ${'points'.tr()}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      {'icon': Icons.camera_alt, 'title': 'home_feature_scan'.tr(),
        'desc': 'home_feature_scan_desc'.tr(), 'color': AppColors.primary, 'screen': 'scan'},
      {'icon': Icons.map, 'title': 'home_feature_map'.tr(),
        'desc': 'home_feature_map_desc'.tr(), 'color': AppColors.accent, 'screen': 'map'},
      {'icon': Icons.card_giftcard, 'title': 'home_feature_reward'.tr(),
        'desc': 'home_feature_reward_desc'.tr(), 'color': AppColors.primaryLight, 'screen': 'reward'},
      {'icon': Icons.info_outlined, 'title': 'home_feature_guide'.tr(),
        'desc': 'home_feature_guide_desc'.tr(), 'color': AppColors.warning, 'screen': 'guide'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: features.map((f) => _buildFeatureCard(
        icon: f['icon'] as IconData,
        title: f['title'] as String,
        desc: f['desc'] as String,
        color: f['color'] as Color,
        screen: f['screen'] as String,
      )).toList(),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required String screen,
  }) {
    return GestureDetector(
      onTap: () => _navigateToScreen(screen),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                      color: AppColors.primaryDark)),
              const SizedBox(height: 2),
              Text(desc,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'Kanit', color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableFAB() {
    return Draggable(
      data: 'chatbot_fab',
      feedback: _buildFABButton(),
      childWhenDragging: Opacity(opacity: 0.5, child: _buildFABButton()),
      child: _buildFABButton(),
    );
  }

  Widget _buildFABButton() {
    return FloatingActionButton.extended(
      heroTag: 'chatbot_fab',
      onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
      icon: const Icon(Icons.chat_bubble_outline),
      label: Text('home_chat'.tr(),
          style: const TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.primary,
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey,
      onTap: (index) {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0: break;
          case 1:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CommunityScreen()));
            break;
          case 2:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RankingScreen()));
            break;
          case 3:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
            break;
        }
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'nav_home'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.people), label: 'nav_community'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.leaderboard), label: 'nav_ranking'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: 'nav_profile'.tr()),
      ],
    );
  }

  void _navigateToScreen(String screen) {
    switch (screen) {
      case 'scan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanWasteScreen()));
        break;
      case 'map':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BinLocationScreen()));
        break;
      case 'reward':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen()));
        break;
      case 'guide':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WasteGuideScreen()));
        break;
    }
  }
}
