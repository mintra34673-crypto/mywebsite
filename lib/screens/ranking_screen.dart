import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'custom_bottom_nav.dart';

// 🎨 ธีมเขียว TreeCard
class _C {
  static const primary = Color(0xFF2D8E6F);
  static const primaryDark = Color(0xFF1B5E48);
  static const primaryLight = Color(0xFF52C77E);
  static const accent = Color(0xFF7FD8B8);
  static const gold = Color(0xFFFFC107);
  static const skyTop = Color(0xFFDCEFF5);
  static const skyMid = Color(0xFFEAF6E9);
  static const bgLight = Color(0xFFF1F8F5);
  static const bgTop = Color(0xFFE3F5EC);
  static const bgBottom = Color(0xFFC8EBD9);
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.locale;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _C.bgBottom,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===== ส่วนหัว: ภาพป่า+พระอาทิตย์ (TreeCard style) =====
            SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                children: [
                  // ภาพป่าวาดด้วย code
                  Positioned.fill(
                    child: CustomPaint(painter: _ForestSunsetPainter()),
                  ),
                  // ปุ่ม back
                  Positioned(
                    top: 4, left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: _C.primaryDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // หัวข้อ
                  Positioned(
                    top: 16, left: 0, right: 0,
                    child: Column(
                      children: [
                        Text('ranking'.tr(),
                            style: const TextStyle(
                                color: _C.primaryDark,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('ranking_subtitle'.tr(),
                            style: TextStyle(
                                color: _C.primaryDark.withOpacity(0.7),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===== รายการอันดับ =====
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('points', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _C.primary));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Text('ranking_empty'.tr()));
                  }

                  // หา index ของ current user
                  int myIndex = -1;
                  for (int i = 0; i < docs.length; i++) {
                    if (docs[i].id == currentUid) {
                      myIndex = i;
                      break;
                    }
                  }

                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_C.bgTop, _C.bgBottom],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // ✅ ลายต้นไม้พื้นหลัง
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            child: CustomPaint(painter: _NatureArtPainter()),
                          ),
                        ),
                        Column(
                          children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: _C.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final isMe = docs[index].id == currentUid;
                              return _rankTile(
                                rank: index + 1,
                                name: data['name'] ?? 'unknown'.tr(),
                                points: (data['points'] as num?)?.toInt() ?? 0,
                                imageUrl: data['profileImage'] as String?,
                                isMe: isMe,
                              );
                            },
                          ),
                        ),
                        // แถบ "You" ด้านล่าง
                        if (myIndex >= 0)
                          _buildYouBar(docs[myIndex].data() as Map<String, dynamic>, myIndex + 1),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildCustomBottomNav(context, 'ranking'),
    );
  }

  Widget _rankTile({
    required int rank,
    required String name,
    required int points,
    required String? imageUrl,
    required bool isMe,
  }) {
    // สีเหรียญ 3 อันดับแรก
    Color? medalColor;
    if (rank == 1) medalColor = _C.gold;
    else if (rank == 2) medalColor = const Color(0xFFE0E0E0);
    else if (rank == 3) medalColor = const Color(0xFFFFCC80);

    final isTop3 = rank <= 3;

    // สีตัวหนังสือ: Top3 = ขาว, อื่น = เขียวเข้ม
    final textColor = isTop3 ? Colors.white : _C.primaryDark;
    final pointColor = isTop3 ? Colors.white : _C.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // ✅ Top3 = เขียวไล่เฉด, อื่น = ขาว
        gradient: isTop3
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.primaryLight, _C.primary, _C.primaryDark],
              )
            : null,
        color: isTop3 ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe && !isTop3
            ? Border.all(color: _C.primary, width: 1.5)
            : (isTop3 ? null : Border.all(color: _C.primary.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: isTop3 ? _C.primary.withOpacity(0.3) : _C.primary.withOpacity(0.05),
            blurRadius: isTop3 ? 12 : 6,
            offset: Offset(0, isTop3 ? 5 : 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ใบไม้จางมุมขวา (เฉพาะ Top3)
          if (isTop3)
            Positioned(
              right: -6, top: -8,
              child: Icon(Icons.eco, size: 54, color: Colors.white.withOpacity(0.15)),
            ),
          Row(
            children: [
              // อันดับ / เหรียญ
              SizedBox(
                width: 36,
                child: medalColor != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: medalColor, size: 24),
                          Text('$rank',
                              style: TextStyle(
                                  color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      )
                    : Text('$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ),
              const SizedBox(width: 12),
              // รูปโปรไฟล์
              CircleAvatar(
                radius: 22,
                backgroundColor: isTop3 ? Colors.white : _C.accent.withOpacity(0.4),
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(Icons.person, color: _C.primary)
                    : null,
              ),
              const SizedBox(width: 14),
              // ชื่อ
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: (isMe || isTop3) ? FontWeight.bold : FontWeight.w600,
                        color: textColor)),
              ),
              // แต้ม
              Row(
                children: [
                  Icon(Icons.eco, size: 16, color: pointColor),
                  const SizedBox(width: 4),
                  Text('$points',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: pointColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYouBar(Map<String, dynamic> data, int rank) {
    final name = data['name'] ?? 'unknown'.tr();
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final imageUrl = data['profileImage'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.primary, _C.primaryDark],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Text('#$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person, color: _C.primary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ranking_you'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.eco, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text('$points',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

// ✅ วาดภาพป่า+พระอาทิตย์ตก สไตล์ TreeCard
class _ForestSunsetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ===== ท้องฟ้าไล่เฉด =====
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_C.skyTop, _C.skyMid, const Color(0xFFF5F3D8)],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, Paint()..shader = skyGradient);

    // ===== ดวงอาทิตย์ =====
    final sunCenter = Offset(w * 0.5, h * 0.62);
    // แสงรอบดวงอาทิตย์ (halo)
    canvas.drawCircle(sunCenter, h * 0.4,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.25));
    canvas.drawCircle(sunCenter, h * 0.3,
        Paint()..color = const Color(0xFFFFE082).withOpacity(0.35));
    // ดวงอาทิตย์
    canvas.drawCircle(sunCenter, h * 0.2,
        Paint()..color = const Color(0xFFFFD54F).withOpacity(0.85));

    // ===== ภูเขาซ้าย-ขวา (ด้านหลัง) =====
    final mtPaint = Paint()..color = const Color(0xFF7EA98F).withOpacity(0.5);
    final mtLeft = Path()
      ..moveTo(0, h * 0.75)
      ..lineTo(w * 0.2, h * 0.42)
      ..lineTo(w * 0.4, h * 0.75)..close();
    canvas.drawPath(mtLeft, mtPaint);
    final mtRight = Path()
      ..moveTo(w * 0.6, h * 0.75)
      ..lineTo(w * 0.82, h * 0.38)
      ..lineTo(w, h * 0.7)
      ..lineTo(w, h * 0.75)..close();
    canvas.drawPath(mtRight, mtPaint);
    // ยอดเขาหิมะ
    final snowPaint = Paint()..color = Colors.white.withOpacity(0.5);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.82, h * 0.38)
        ..lineTo(w * 0.76, h * 0.48)
        ..lineTo(w * 0.79, h * 0.46)
        ..lineTo(w * 0.82, h * 0.5)
        ..lineTo(w * 0.85, h * 0.46)
        ..lineTo(w * 0.88, h * 0.48)..close(),
      snowPaint,
    );

    // ===== ป่าสน หลายชั้น (อ่อน→เข้ม) =====
    // ชั้นไกล (อ่อน)
    _forestLayer(canvas, w, h, h * 0.68, const Color(0xFF9CCC9E), 0.6, 7);
    // ชั้นกลาง
    _forestLayer(canvas, w, h, h * 0.76, const Color(0xFF66BB6A), 0.8, 9);
    // ชั้นหน้า (เข้ม)
    _forestLayer(canvas, w, h, h * 0.85, const Color(0xFF2E7D32), 1.0, 11);
    // ชั้นหน้าสุด (เข้มสุด)
    _forestLayer(canvas, w, h, h * 0.95, const Color(0xFF1B5E48), 1.2, 13);

    // ===== นกบิน =====
    final birdPaint = Paint()
      ..color = _C.primaryDark.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _bird(canvas, Offset(w * 0.25, h * 0.25), 8, birdPaint);
    _bird(canvas, Offset(w * 0.72, h * 0.2), 10, birdPaint);
    _bird(canvas, Offset(w * 0.8, h * 0.3), 7, birdPaint);
  }

  // วาดป่าสน 1 ชั้น
  void _forestLayer(Canvas canvas, double w, double h, double baseY,
      Color color, double scale, int count) {
    final paint = Paint()..color = color;
    final treeW = w / count;
    for (int i = 0; i <= count; i++) {
      final cx = treeW * i + (i.isEven ? treeW * 0.3 : 0);
      final treeH = 40.0 * scale;
      final path = Path()
        ..moveTo(cx, baseY - treeH)
        ..lineTo(cx - treeW * 0.4, baseY)
        ..lineTo(cx + treeW * 0.4, baseY)..close();
      canvas.drawPath(path, paint);
    }
    // พื้นสีเดียวกันด้านล่าง
    canvas.drawRect(Rect.fromLTWH(0, baseY - 2, w, h - baseY + 2), paint);
  }

  void _bird(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - s * 0.4, c.dy - s * 0.5, c.dx, c.dy)
      ..quadraticBezierTo(c.dx + s * 0.4, c.dy - s * 0.5, c.dx + s, c.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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