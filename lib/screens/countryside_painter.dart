import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ภาพ Countryside: เกาะลอย + ภูเขาหิมะ + กังหันลม + บ้าน + สัตว์
/// (ย้ายมาจาก home_screen.dart เดิม เพื่อให้หน้าอื่นเรียกใช้ร่วมกันได้)
///
/// ออกแบบมาให้ใช้กับกล่องแนวนอนเตี้ยๆ เช่น:
/// SizedBox(height: 200, width: double.infinity, child: CustomPaint(painter: CountrysideScenePainter()))
class CountrysideScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ===== เกาะลอย (ฐานดินโค้ง) =====
    final islandTop = h * 0.62;
    // เงาสะท้อนใต้เกาะ (จาง)
    final reflection = Path()
      ..moveTo(w * 0.1, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 1.05, w * 0.9, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.1, h * 0.82)
      ..close();
    canvas.drawPath(reflection, Paint()..color = const Color(0xFF81C784).withOpacity(0.3));

    // ดินชั้นล่าง (เข้ม)
    final soilDark = Path()
      ..moveTo(w * 0.05, islandTop + 8)
      ..lineTo(w * 0.95, islandTop + 8)
      ..quadraticBezierTo(w * 0.5, h * 0.9, w * 0.05, islandTop + 8)
      ..close();
    canvas.drawPath(soilDark, Paint()..color = const Color(0xFF1B5E48));

    // หญ้าเขียว (บนเกาะ)
    final grass = Path()
      ..moveTo(w * 0.05, islandTop)
      ..lineTo(w * 0.95, islandTop)
      ..lineTo(w * 0.95, islandTop + 12)
      ..lineTo(w * 0.05, islandTop + 12)
      ..close();
    canvas.drawPath(grass, Paint()..color = const Color(0xFF4CAF50));

    // ===== เนินหญ้าบนเกาะ (โค้งๆ) =====
    _hill(canvas, w * 0.35, islandTop, w * 0.5, 30, const Color(0xFF66BB6A));
    _hill(canvas, w * 0.6, islandTop, w * 0.45, 26, const Color(0xFF81C784));

    // ===== ภูเขาหิมะ (ซ้าย) =====
    _snowMountain(canvas, Offset(w * 0.14, islandTop), 55);
    _snowMountain(canvas, Offset(w * 0.22, islandTop), 42);
    // ===== ภูเขาหิมะ (ขวา) =====
    _snowMountain(canvas, Offset(w * 0.8, islandTop), 60);

    // ===== ต้นสน =====
    _pine(canvas, Offset(w * 0.1, islandTop), 32, const Color(0xFF2E7D32));
    _pine(canvas, Offset(w * 0.44, islandTop - 15), 40, const Color(0xFF388E3C));
    _pine(canvas, Offset(w * 0.52, islandTop - 12), 34, const Color(0xFF2E7D32));
    _pine(canvas, Offset(w * 0.68, islandTop - 8), 30, const Color(0xFF388E3C));
    _pine(canvas, Offset(w * 0.88, islandTop), 28, const Color(0xFF2E7D32));

    // ===== กังหันลม (เสาปักดินถึง islandTop) =====
    _windmill(canvas, Offset(w * 0.3, islandTop + 6), 75);
    _windmill(canvas, Offset(w * 0.5, islandTop + 6), 72);
    _windmill(canvas, Offset(w * 0.92, islandTop + 6), 60);

    // ===== บ้าน (หลังคาส้ม ซ้าย) =====
    _house(canvas, Offset(w * 0.28, islandTop - 2), 1.0, const Color(0xFFE67E22));
    // ===== บ้าน (หลังคาส้ม ขวา) =====
    _house(canvas, Offset(w * 0.6, islandTop - 4), 0.9, const Color(0xFFE67E22));

    // ===== เมฆ =====
    _cloud(canvas, Offset(w * 0.18, h * 0.28), 20);
    _cloud(canvas, Offset(w * 0.72, h * 0.22), 24);

    // ===== สัตว์ (แกะ/วัว จุดขาวเล็กๆ) =====
    _sheep(canvas, Offset(w * 0.24, islandTop - 4));
    _sheep(canvas, Offset(w * 0.66, islandTop - 6));
    _sheep(canvas, Offset(w * 0.7, islandTop - 4));
  }

  void _hill(Canvas canvas, double cx, double baseY, double width, double height, Color color) {
    final path = Path()
      ..moveTo(cx - width / 2, baseY)
      ..quadraticBezierTo(cx, baseY - height, cx + width / 2, baseY)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _snowMountain(Canvas canvas, Offset base, double hgt) {
    final cx = base.dx;
    final mt = Path()
      ..moveTo(cx, base.dy - hgt)
      ..lineTo(cx - hgt * 0.6, base.dy)
      ..lineTo(cx + hgt * 0.6, base.dy)..close();
    canvas.drawPath(mt, Paint()..color = const Color(0xFF5D8A6B));
    final shadow = Path()
      ..moveTo(cx, base.dy - hgt)
      ..lineTo(cx + hgt * 0.6, base.dy)
      ..lineTo(cx, base.dy)..close();
    canvas.drawPath(shadow, Paint()..color = const Color(0xFF456B54));
    final snow = Path()
      ..moveTo(cx, base.dy - hgt)
      ..lineTo(cx - hgt * 0.22, base.dy - hgt * 0.62)
      ..lineTo(cx - hgt * 0.1, base.dy - hgt * 0.68)
      ..lineTo(cx, base.dy - hgt * 0.58)
      ..lineTo(cx + hgt * 0.1, base.dy - hgt * 0.68)
      ..lineTo(cx + hgt * 0.22, base.dy - hgt * 0.62)..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
  }

  void _pine(Canvas canvas, Offset base, double hgt, Color color) {
    final cx = base.dx;
    canvas.drawRect(Rect.fromLTWH(cx - 2.5, base.dy - hgt * 0.1, 5, hgt * 0.18),
        Paint()..color = const Color(0xFF6D4C41));
    final paint = Paint()..color = color;
    for (int i = 0; i < 3; i++) {
      final top = base.dy - hgt + (hgt * 0.28 * i);
      final bottom = top + hgt * 0.4;
      final lw = (hgt * 0.3) * (1 - i * 0.2);
      canvas.drawPath(Path()
        ..moveTo(cx, top)..lineTo(cx - lw, bottom)..lineTo(cx + lw, bottom)..close(), paint);
    }
  }

  void _windmill(Canvas canvas, Offset base, double hgt) {
    final cx = base.dx;
    final topY = base.dy - hgt;
    canvas.drawLine(Offset(cx, base.dy), Offset(cx, topY),
        Paint()..color = Colors.white..strokeWidth = 3);
    final blade = Paint()..color = const Color(0xFF7EA98F);
    for (int i = 0; i < 3; i++) {
      final ang = (i * 120 - 90) * math.pi / 180;
      final path = Path()
        ..moveTo(cx, topY)
        ..lineTo(cx + 16 * math.cos(ang - 0.15), topY + 16 * math.sin(ang - 0.15))
        ..lineTo(cx + 18 * math.cos(ang), topY + 18 * math.sin(ang))
        ..close();
      canvas.drawPath(path, blade);
    }
    canvas.drawCircle(Offset(cx, topY), 3, Paint()..color = Colors.white);
  }

  void _house(Canvas canvas, Offset base, double scale, Color roofColor) {
    final bw = 32.0 * scale, bh = 20.0 * scale;
    canvas.drawRect(Rect.fromLTWH(base.dx - bw / 2, base.dy - bh, bw, bh),
        Paint()..color = const Color(0xFFFFF3E0));
    final roof = Path()
      ..moveTo(base.dx - bw / 2 - 3, base.dy - bh)
      ..lineTo(base.dx - bw * 0.2, base.dy - bh - 12 * scale)
      ..lineTo(base.dx + bw / 2 + 3, base.dy - bh)..close();
    canvas.drawPath(roof, Paint()..color = roofColor);
    canvas.drawRect(
        Rect.fromLTWH(base.dx - 4 * scale, base.dy - 10 * scale, 8 * scale, 10 * scale),
        Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRect(
        Rect.fromLTWH(base.dx - bw * 0.4, base.dy - bh * 0.8, 6 * scale, 6 * scale),
        Paint()..color = const Color(0xFFFFD54F));
  }

  void _cloud(Canvas canvas, Offset c, double r) {
    final fill = Paint()..color = const Color(0xFFB2DFDB).withOpacity(0.6);
    canvas.drawCircle(c, r * 0.6, fill);
    canvas.drawCircle(c + Offset(-r * 0.5, r * 0.1), r * 0.45, fill);
    canvas.drawCircle(c + Offset(r * 0.5, r * 0.1), r * 0.5, fill);
    final rain = Paint()..color = const Color(0xFFB2DFDB).withOpacity(0.35)..strokeWidth = 2;
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(c + Offset(i * r * 0.4, r * 0.5), c + Offset(i * r * 0.4, r * 1.8), rain);
    }
  }

  void _sheep(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 4, Paint()..color = Colors.white);
    canvas.drawCircle(c + const Offset(3, 1), 2, Paint()..color = const Color(0xFF5D4037));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}