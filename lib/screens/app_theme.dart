import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// 🎨 ธีมเขียว BinSort — ใช้ร่วมกันทุกหน้า
// import ไฟล์นี้แทนการประกาศสีซ้ำในแต่ละไฟล์ (ป้องกัน error "already defined")
const kPrimaryGreen = Color(0xFF2D8E6F);
const kDarkGreen = Color(0xFF1B5E48);
const kLightGreen = Color(0xFF52C77E);
const kAccentGreen = Color(0xFF7FD8B8);
const kScreenBg = Color(0xFFF5FFF8);

// ✅ เปิดให้ลากด้วยเมาส์ได้บน Flutter Web สำหรับ PageView/ListView แนวนอนทุกจุด
// (ปกติ default ของ Flutter จะลากได้แค่บนมือถือ/แตะจอเท่านั้น)
// ใช้ร่วมกันทุกไฟล์ที่มี carousel: ScrollConfiguration(behavior: MouseDragScrollBehavior(), child: PageView(...))
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}