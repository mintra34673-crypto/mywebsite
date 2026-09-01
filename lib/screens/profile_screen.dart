import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'edit_information_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

// 🎨 ธีมเขียวธรรมชาติ BinSort
class _C {
  static const primary = Color(0xFF2D8E6F);
  static const primaryDark = Color(0xFF1B5E48);
  static const primaryLight = Color(0xFF52C77E);
  static const accent = Color(0xFF7FD8B8);
  static const mint = Color(0xFFB8E6D0);
  static const lime = Color(0xFFC5E17A);
  static const cream = Color(0xFFF7FBEF);
  static const bgTop = Color(0xFFF3F9E8);
  static const bgBottom = Color(0xFFE0F0D5);
  static const card = Color(0xFFFFFFFF);
  
  // 🔴 สีแดงสำหรับปุ่ม Logout
  static const danger = Color(0xFFE53935);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _changeLanguage(String langCode) async {
    await context.setLocale(Locale(langCode));
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showLanguageDialog() async {
    final currentLang = context.locale.languageCode;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text('choose_language'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: _C.primaryDark)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇹🇭", style: TextStyle(fontSize: 24)),
              title: Text('thai_language'.tr()),
              trailing: Radio<String>(
                value: 'th', groupValue: currentLang, activeColor: _C.primary,
                onChanged: (val) { Navigator.pop(dialogContext); if (val != null) _changeLanguage(val); },
              ),
              onTap: () { Navigator.pop(dialogContext); _changeLanguage('th'); },
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
              title: Text('english_language'.tr()),
              trailing: Radio<String>(
                value: 'en', groupValue: currentLang, activeColor: _C.primary,
                onChanged: (val) { Navigator.pop(dialogContext); if (val != null) _changeLanguage(val); },
              ),
              onTap: () { Navigator.pop(dialogContext); _changeLanguage('en'); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    return Scaffold(
      backgroundColor: _C.bgTop,
      appBar: AppBar(
        backgroundColor: _C.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('profile'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ✅ พื้นหลังไล่เฉดครีม-เขียว
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_C.bgTop, _C.bgBottom],
              ),
            ),
          ),
          // ✅ ลายธรรมชาติ line-art (ต้นไม้ เมฆ วงกลม เนินเขา ใบไม้)
          Positioned.fill(
            child: CustomPaint(painter: _NatureArtPainter()),
          ),
          // ✅ เนื้อหา
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _C.primary));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('no_user_data_found'.tr()));
              }
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String name = data['name'] ?? 'unknown'.tr();
              int points = data['points'] ?? 0;
              String phone = data['phone'] ?? "-";
              String? profileImage = data['profileImage'];

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildUserCard(name, points, profileImage),
                    const SizedBox(height: 28),
                    _sectionTitle('personal_info'.tr(), Icons.person_outline),
                    _infoTile(Icons.phone, phone, _C.primary),
                    _infoTile(Icons.email, user?.email ?? "-", _C.primaryLight),
                    const SizedBox(height: 26),
                    _sectionTitle('settings'.tr(), Icons.settings_outlined),
                    _settingsTile(Icons.person, 'edit_information'.tr(), _C.primary, () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const EditInformationScreen()));
                    }),
                    _settingsTile(Icons.language, 'change_language'.tr(), _C.primaryLight, _showLanguageDialog),
                    const SizedBox(height: 40),
                    _logoutButton(context),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String name, int points, String? imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.primaryLight, _C.primary, _C.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, top: -10,
            child: Icon(Icons.eco, size: 70, color: Colors.white.withOpacity(0.15)),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? const Icon(Icons.person, size: 40, color: _C.primary)
                    : null,
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(" $points ${'points'.tr()}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 12, right: 24),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _C.primaryDark),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _C.primaryDark)),
          ],
        ),
      );

  Widget _infoTile(IconData icon, String text, Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.cream.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.accent.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _C.primary.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600, color: _C.primaryDark))),
          ],
        ),
      );

  Widget _settingsTile(IconData icon, String text, Color accentColor, VoidCallback onTap) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.mint.withOpacity(0.85), _C.accent.withOpacity(0.55)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.primary.withOpacity(0.18)),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: _C.primaryDark, size: 20),
          ),
          title: Text(text,
              style: const TextStyle(fontWeight: FontWeight.bold, color: _C.primaryDark)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _C.primary),
        ),
      );

  // 🔴 ปุ่ม Logout ปรับเป็นสีแดงเรียบร้อยครับ
  Widget _logoutButton(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.danger,
          shadowColor: _C.danger.withOpacity(0.4),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
          elevation: 4,
        ),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.white),
            const SizedBox(width: 10),
            Text('logout'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

// ✅ ลายธรรมชาติกระจายทั่วจอ + หลากหลาย (ต้นไม้ เมฆ ใบไม้ วงกลม เนินเขา)
class _NatureArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final darkGreen = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.15);
    final medGreen = Paint()..color = const Color(0xFF66BB6A).withOpacity(0.15);
    final limeGreen = Paint()..color = const Color(0xFFAED581).withOpacity(0.16);
    final greyGreen = Paint()..color = const Color(0xFF9E9E9E).withOpacity(0.10);
    final trunkFill = Paint()..color = const Color(0xFF8D6E63).withOpacity(0.18);
    final cloudFill = Paint()..color = Colors.white.withOpacity(0.38);
    final line = Paint()
      ..color = const Color(0xFF1B5E48).withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // ===== เนินเขาด้านล่างสุด =====
    final hill1 = Path()
      ..moveTo(w * 0.3, h)
      ..quadraticBezierTo(w * 0.65, h * 0.91, w, h * 0.95)
      ..lineTo(w, h)..close();
    canvas.drawPath(hill1, darkGreen);
    final hill2 = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(w * 0.2, h * 0.96, w * 0.4, h * 0.98)
      ..lineTo(w * 0.4, h)..close();
    canvas.drawPath(hill2, medGreen);

    // ===== เมฆ กระจาย 4 ก้อน ทั่วส่วนบน =====
    _drawCloud(canvas, Offset(w * 0.8, h * 0.05), 46, cloudFill, line);
    _drawCloud(canvas, Offset(w * 0.25, h * 0.07), 38, cloudFill, line);
    _drawCloud(canvas, Offset(w * 0.55, h * 0.28), 32, cloudFill, line);
    _drawCloud(canvas, Offset(w * 0.15, h * 0.42), 28, cloudFill, line);

    // ===== ต้นไม้ กระจาย 5 ต้น หลายทรง/ขนาด ทั่วจอ =====
    // ใหญ่ ขวาล่าง
    _drawRealTree(canvas, Offset(w * 0.88, h * 0.8), 50,
        darkGreen, medGreen, limeGreen, trunkFill, line);
    // สน ซ้ายล่าง
    _drawPineTree(canvas, Offset(w * 0.12, h * 0.85), 66,
        darkGreen, medGreen, trunkFill, line);
    // กลาง (โซนล่าง ระหว่างการ์ดกับปุ่ม)
    _drawRealTree(canvas, Offset(w * 0.5, h * 0.9), 38,
        medGreen, darkGreen, limeGreen, trunkFill, line);
    // เล็ก ขวากลาง (ริมขอบ)
    _drawRealTree(canvas, Offset(w * 0.96, h * 0.5), 28,
        medGreen, limeGreen, limeGreen, trunkFill, line);
    // สนเล็ก ขวาบน
    _drawPineTree(canvas, Offset(w * 0.9, h * 0.22), 40,
        medGreen, limeGreen, trunkFill, line);

    // ===== ก้านใบไม้ กระจาย 3 จุด =====
    _drawLeafSprig(canvas, Offset(w * 0.04, h * 0.04), line, medGreen, 1.0);
    _drawLeafSprig(canvas, Offset(w * 0.68, h * 0.44), line, limeGreen, 0.75);
    _drawLeafSprig(canvas, Offset(w * 0.35, h * 0.15), line, medGreen, 0.6);

    // ===== วงกลม cluster 2 จุด =====
    _drawCircleCluster(canvas, Offset(w * 0.05, h * 0.62), line, limeGreen, greyGreen, 1.0);
    _drawCircleCluster(canvas, Offset(w * 0.85, h * 0.64), line, medGreen, limeGreen, 0.7);

    // ===== ใบไม้เดี่ยว กระจายเล็กๆ =====
    _leaf(canvas, Offset(w * 0.45, h * 0.05), 18, 0.3, limeGreen, line);
    _leaf(canvas, Offset(w * 0.3, h * 0.55), 15, -0.5, medGreen, line);
    _leaf(canvas, Offset(w * 0.75, h * 0.72), 16, 1.2, limeGreen, line);
  }

  void _drawCloud(Canvas canvas, Offset c, double r, Paint fill, Paint line) {
    final path = Path();
    path.addOval(Rect.fromCircle(center: c, radius: r * 0.6));
    path.addOval(Rect.fromCircle(center: c + Offset(-r * 0.5, r * 0.15), radius: r * 0.5));
    path.addOval(Rect.fromCircle(center: c + Offset(r * 0.5, r * 0.15), radius: r * 0.55));
    path.addOval(Rect.fromCircle(center: c + Offset(0, r * 0.3), radius: r * 0.65));
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
  }

  void _drawRealTree(Canvas canvas, Offset base, double r,
      Paint dark, Paint med, Paint lime, Paint trunk, Paint line) {
    final trunkPath = Path()
      ..moveTo(base.dx - r * 0.14, base.dy + r * 0.05)
      ..quadraticBezierTo(base.dx - r * 0.06, base.dy - r * 0.3,
          base.dx - r * 0.05, base.dy - r * 0.5)
      ..lineTo(base.dx + r * 0.05, base.dy - r * 0.5)
      ..quadraticBezierTo(base.dx + r * 0.06, base.dy - r * 0.3,
          base.dx + r * 0.14, base.dy + r * 0.05)
      ..close();
    canvas.drawPath(trunkPath, trunk);
    canvas.drawPath(trunkPath, line);

    final branchStart = base + Offset(0, -r * 0.45);
    canvas.drawLine(branchStart, branchStart + Offset(-r * 0.4, -r * 0.25), line);
    canvas.drawLine(branchStart + Offset(0, r * 0.05),
        branchStart + Offset(r * 0.4, -r * 0.2), line);

    final crownCenter = base + Offset(0, -r * 0.75);
    final blobs = [
      [-0.55, 0.15, 0.42, lime], [0.55, 0.1, 0.45, dark],
      [-0.3, -0.35, 0.4, med], [0.35, -0.3, 0.48, lime],
      [0.0, 0.3, 0.5, med], [-0.15, -0.05, 0.6, med],
      [0.2, -0.05, 0.55, dark], [0.0, -0.5, 0.38, lime],
    ];
    for (final b in blobs) {
      final pos = crownCenter + Offset(r * (b[0] as double), r * (b[1] as double));
      canvas.drawCircle(pos, r * (b[2] as double), b[3] as Paint);
    }
    canvas.drawCircle(crownCenter + Offset(0, -r * 0.5), r * 0.38, line);
    canvas.drawCircle(crownCenter + Offset(0.35 * r, -r * 0.3), r * 0.48, line);
    canvas.drawCircle(crownCenter + Offset(-0.3 * r, -r * 0.35), r * 0.4, line);
  }

  void _drawPineTree(Canvas canvas, Offset base, double hgt,
      Paint dark, Paint med, Paint trunk, Paint line) {
    final cx = base.dx;
    final topY = base.dy - hgt;
    final width = hgt * 0.45;
    final trunkRect = Path()
      ..moveTo(cx - 4, base.dy)
      ..lineTo(cx - 3, base.dy - hgt * 0.12)
      ..lineTo(cx + 3, base.dy - hgt * 0.12)
      ..lineTo(cx + 4, base.dy)..close();
    canvas.drawPath(trunkRect, trunk);
    canvas.drawPath(trunkRect, line);
    for (int i = 0; i < 4; i++) {
      final layerTop = topY + (hgt * 0.22 * i);
      final layerBottom = layerTop + hgt * 0.36;
      final layerW = width * (1 - i * 0.18);
      final tri = Path()
        ..moveTo(cx, layerTop)
        ..lineTo(cx - layerW, layerBottom)
        ..lineTo(cx + layerW, layerBottom)..close();
      canvas.drawPath(tri, i.isEven ? dark : med);
      canvas.drawPath(tri, line);
    }
  }

  void _drawLeafSprig(Canvas canvas, Offset start, Paint line, Paint fill, double scale) {
    final end = start + Offset(65 * scale, 45 * scale);
    canvas.drawLine(start, end, line);
    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      final pos = start + Offset(65 * scale * t, 45 * scale * t);
      _leaf(canvas, pos, 15 * scale, -0.8, fill, line);
      _leaf(canvas, pos, 15 * scale, 0.8, fill, line);
    }
    _leaf(canvas, end, 17 * scale, 0.2, fill, line);
  }

  void _leaf(Canvas canvas, Offset c, double s, double rot, Paint fill, Paint line) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(s * 0.6, -s * 0.5, s * 1.4, 0)
      ..quadraticBezierTo(s * 0.6, s * 0.5, 0, 0)..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
    canvas.restore();
  }

  void _drawCircleCluster(Canvas canvas, Offset c, Paint line, Paint fill1, Paint fill2, double scale) {
    final positions = [
      Offset(0, 0), Offset(32 * scale, -18 * scale), Offset(18 * scale, 28 * scale),
      Offset(48 * scale, 12 * scale), Offset(-15 * scale, 22 * scale), Offset(40 * scale, -32 * scale),
    ];
    final sizes = [18.0, 14.0, 20.0, 13.0, 16.0, 11.0];
    for (int i = 0; i < positions.length; i++) {
      final p = c + positions[i];
      if (i > 0) canvas.drawLine(c, p, line);
      canvas.drawCircle(p, sizes[i] * scale, i % 2 == 0 ? fill1 : fill2);
      canvas.drawCircle(p, sizes[i] * scale, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}