import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ranking_screen.dart';
import 'profile_screen.dart';
import 'scan_waste_screen.dart';
import 'rewards_screen.dart'; // ✅ สำหรับเปิด CouponDetailScreen
import 'custom_bottom_nav.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  String _translateBinTypes(String raw) {
    if (raw.trim().isEmpty) return '';
    final map = {
      'ทั่วไป': 'bintype_general',
      'รีไซเคิล': 'bintype_recycle',
      'อินทรีย์': 'bintype_organic',
      'อันตราย': 'bintype_hazardous',
    };
    final parts = raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    return parts.map((p) => map.containsKey(p) ? map[p]!.tr() : p).join(', ');
  }

  // ✅ แปลง label ขยะให้เปลี่ยนตามภาษาปัจจุบัน (TH / EN)
  String _translateLabel(BuildContext context, String rawLabel) {
    if (rawLabel.isEmpty || rawLabel == '-') return '-';
    
    final key = rawLabel.trim().toLowerCase();
    final isThai = context.locale.languageCode == 'th';

    // Map ภาษาแยกตามความเหมาะสม
    final translations = {
      'plastic': isThai ? 'พลาสติก' : 'Plastic',
      'glass': isThai ? 'แก้ว' : 'Glass',
      'paper': isThai ? 'กระดาษ' : 'Paper',
      'metal': isThai ? 'โลหะ/กระป๋อง' : 'Metal',
      'organic': isThai ? 'ขยะอินทรีย์' : 'Organic',
      'general': isThai ? 'ขยะทั่วไป' : 'General',
      'hazardous': isThai ? 'ขยะอันตราย' : 'Hazardous',
      'can': isThai ? 'กระป๋อง' : 'Can',
      'bottle': isThai ? 'ขวด' : 'Bottle',
    };

    if (translations.containsKey(key)) {
      return translations[key]!;
    }

    return key.tr();
  }

  // ✅ รวม scan_history + activities + redemptions
  Stream<List<Map<String, dynamic>>> _mergedStream(String uid) {
    final scanStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('scan_history')
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), '_source': 'scan'}).toList());

    return scanStream.asyncMap((scanList) async {
      // activities
      final actSnap = await FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: uid)
          .get();
      final actList = actSnap.docs
          .map((d) => {...d.data(), '_source': 'activity'})
          .toList();

      // ✅ redemptions (ประวัติแลกรางวัล)
      final redSnap = await FirebaseFirestore.instance
          .collection('redemptions')
          .where('userId', isEqualTo: uid)
          .get();
      final redList = redSnap.docs
          .map((d) => {...d.data(), '_id': d.id, '_source': 'redemption'})
          .toList();

      final all = [...scanList, ...actList, ...redList];
      all.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
        final tb = (b['timestamp'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return all;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'activity'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? Center(child: Text('activity_login_required'.tr()))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _mergedStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return Center(child: Text('activity_no_history'.tr()));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildCard(context, docs[index]),
                );
              },
            ),
      bottomNavigationBar: buildCustomBottomNav(context, 'activity'),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    final source = data['_source'] as String? ?? 'scan';

    // ✅ การ์ดประวัติแลกรางวัล
    if (source == 'redemption') {
      final rewardName = data['rewardName'] as String? ?? '-';
      final pointsCost = (data['pointsCost'] as num?)?.toInt() ?? 0;
      final code = data['code'] as String? ?? '';
      final used = data['used'] == true;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final dateStr = createdAt != null
          ? '${createdAt.day}/${createdAt.month}/${createdAt.year}  '
            '${createdAt.hour.toString().padLeft(2, '0')}:'
            '${createdAt.minute.toString().padLeft(2, '0')}'
          : '-';
      final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

      return GestureDetector(
        onTap: expiresAt != null
            ? () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CouponDetailScreen(
                      rewardName: rewardName, code: code, expiry: expiresAt,
                      initialUsed: used),
                ))
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
                child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('activity_redeem_reward'.tr(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(rewardName, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    Text(code, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('-$pointsCost ${'points'.tr()}',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: used ? Colors.grey.shade300 : isExpired ? Colors.red.shade100 : const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      used ? 'coupon_used'.tr() : isExpired ? 'coupon_expired'.tr() : 'coupon_redeemed'.tr(),
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: used ? Colors.grey.shade700 : isExpired ? Colors.red.shade700 : const Color(0xFF4CAF50)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // การ์ดเพิ่มถังขยะ
    if (source == 'activity' && data['type'] == 'add_bin') {
      final name = data['detail'] as String? ?? '-';
      final points = data['points'] as int? ?? 2;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = timestamp != null
          ? '${timestamp.day}/${timestamp.month}/${timestamp.year}  '
            '${timestamp.hour.toString().padLeft(2, '0')}:'
            '${timestamp.minute.toString().padLeft(2, '0')}'
          : '-';
      final rawTypes = (data['binTypes'] as List?)?.join(', ') ?? '';
      final types = _translateBinTypes(rawTypes);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
              child: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('activity_add_bin'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  if (types.isNotEmpty)
                    Text(types, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              '+$points ${'points'.tr()}',
              style: const TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // ✅ การ์ดสแกนขยะ
    final rawLabel = data['label'] as String? ?? '-';
    final label = _translateLabel(context, rawLabel); // 👈 ส่ง context เข้าไปสลับภาษาอัตโนมัติ
    final points = data['pointsEarned'] as int? ?? data['points'] as int? ?? 0;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final dateStr = timestamp != null
        ? '${timestamp.day}/${timestamp.month}/${timestamp.year}  '
          '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}'
        : '-';
    final distanceMeters = (data['distanceMeters'] as num?)?.toDouble() ?? -1.0;
    final withinRadius = data['withinRadius'] as bool? ?? false;
    final categoryId = data['categoryId'] as String? ?? 'general';
    final catColor = _categoryColor(categoryId);
    final catIcon = _categoryIcon(categoryId);

    String distText;
    Color distBg, distBorder, distTextColor, distIconColor;

    if (distanceMeters < 0) {
      distText = 'activity_no_location'.tr();
      distBg = Colors.grey.shade100;
      distBorder = Colors.grey;
      distTextColor = Colors.grey;
      distIconColor = Colors.grey;
    } else if (withinRadius) {
      distText = 'activity_within_radius'.tr(
          namedArgs: {'dist': distanceMeters.toStringAsFixed(1)});
      distBg = const Color(0xFFE8F5E9);
      distBorder = const Color(0xFF2E7D32);
      distTextColor = const Color(0xFF388E3C);
      distIconColor = const Color(0xFF2E7D32);
    } else {
      distText = 'activity_out_of_radius'.tr(
          namedArgs: {'dist': distanceMeters.toStringAsFixed(1)});
      distBg = const Color(0xFFFFEBEE);
      distBorder = const Color(0xFFF44336);
      distTextColor = const Color(0xFFB71C1C);
      distIconColor = const Color(0xFFF44336);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: catColor.withOpacity(0.12),
                child: Icon(catIcon, color: catColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                points > 0
                    ? '+$points ${'points'.tr()}'
                    : 'activity_no_points'.tr(),
                style: TextStyle(
                  color: points > 0 ? const Color(0xFF66BB6A) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: distBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: distBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 13, color: distIconColor),
                const SizedBox(width: 4),
                Text(distText,
                    style: TextStyle(fontSize: 11, color: distTextColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String categoryId) {
    switch (categoryId) {
      case 'recyclable': return const Color(0xFFF9A825);
      case 'organic':    return const Color(0xFF2E7D32);
      case 'hazardous':  return const Color(0xFFB71C1C);
      default:           return const Color(0xFF1565C0);
    }
  }

  IconData _categoryIcon(String categoryId) {
    switch (categoryId) {
      case 'recyclable': return Icons.recycling;
      case 'organic':    return Icons.eco;
      case 'hazardous':  return Icons.warning_amber_rounded;
      default:           return Icons.delete_outline;
    }
  }
}