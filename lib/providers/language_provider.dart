// lib/providers/language_provider.dart - FIXED
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('th');

  Locale get locale => _locale;

  // ✅ ลบ _loadSavedLanguage() ตอน constructor ออก
  // เพราะ EasyLocalization โหลด/จำภาษาให้เองอยู่แล้ว
  // ถ้าโหลดซ้ำจะชนกัน = ภาษาไม่เปลี่ยน

  // ✅ sync ค่าปัจจุบันจาก EasyLocalization (เรียกครั้งเดียวตอนเปิดหน้า Profile)
  void syncFromContext(BuildContext context) {
    _locale = context.locale;
  }

  // ✅ เปลี่ยนภาษา - ให้ EasyLocalization เป็นคนคุมหลัก
  Future<void> setLanguage(String languageCode, BuildContext context) async {
    final newLocale = Locale(languageCode);

    // 1. บอก EasyLocalization เปลี่ยนภาษา (ตัวนี้คุมจริง + จำให้อัตโนมัติ)
    await context.setLocale(newLocale);

    // 2. update ค่าใน provider แล้วแจ้ง listeners
    _locale = newLocale;
    notifyListeners();

    // 3. เก็บ backup ใน SharedPreferences (เผื่อใช้ที่อื่น)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', languageCode);
    } catch (_) {}
  }
}