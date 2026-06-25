import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ranking_screen.dart';
import 'profile_screen.dart';
import 'scan_waste_screen.dart';
import 'my_qr_code_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  // ── รวม scan_history + activities แล้ว sort ตาม timestamp ────────────────
  Stream<List<Map<String, dynamic>>> _mergedStream(String uid) {
    final scanStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('scan_history')
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), '_source': 'scan'}).toList());

    final actStream = FirebaseFirestore.instance
        .collection('activities')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), '_source': 'activity'}).toList());

    return scanStream.asyncMap((scanList) async {
      // ดึง activities แบบ one-shot แล้วรวม
      final actSnap = await FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: uid)
          .get();
      final actList = actSnap.docs
          .map((d) => {...d.data(), '_source': 'activity'})
          .toList();

      final all = [...scanList, ...actList];
      all.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?);
        final tb = (b['timestamp'] as Timestamp?);
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
          ? const Center(child: Text('กรุณาเข้าสู่ระบบ'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _mergedStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('ยังไม่มีประวัติกิจกรรม'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildCard(docs[index]),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4B996),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyQrCodeScreen()),
        ),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(context, Icons.home, 'หน้าหลัก', false,
                  onTap: () => Navigator.pop(context)),
              _buildNavIcon(context, Icons.grid_view_rounded, 'กิจกรรม', true,
                  onTap: () {}),
              const SizedBox(width: 40),
              _buildNavIcon(context, Icons.leaderboard_outlined, 'จัดอันดับ', false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RankingScreen()))),
              _buildNavIcon(context, Icons.person_outline, 'โปรไฟล์', false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final source = data['_source'] as String? ?? 'scan';

    // ── กรณีเพิ่มจุดถัง ──────────────────────────────────────────────────────
    if (source == 'activity' && data['type'] == 'add_bin') {
      final name = data['detail'] as String? ?? 'ถังขยะ';
      final points = data['points'] as int? ?? 2;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = timestamp != null
          ? '${timestamp.day}/${timestamp.month}/${timestamp.year}  '
            '${timestamp.hour.toString().padLeft(2, '0')}:'
            '${timestamp.minute.toString().padLeft(2, '0')}'
          : '-';
      final types = (data['binTypes'] as List?)?.join(', ') ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
              child: const Icon(Icons.add_location_alt_outlined,
                  color: Color(0xFF4CAF50)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เพิ่มจุดถังขยะ',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(name,
                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  if (types.isNotEmpty)
                    Text(types,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              '+$points แต้ม',
              style: const TextStyle(
                color: Color(0xFF66BB6A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // ── กรณีสแกนขยะ (scan_history เดิม) ─────────────────────────────────────
    final label = data['label'] as String? ?? 'ไม่ทราบ';
    final points = data['pointsEarned'] as int?
        ?? data['points'] as int?
        ?? 0;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                points > 0 ? '+$points แต้ม' : 'ไม่ได้แต้ม',
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
              color: distanceMeters < 0
                  ? Colors.grey.shade100
                  : withinRadius
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: distanceMeters < 0
                    ? Colors.grey.shade300
                    : withinRadius
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF44336),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on,
                    size: 13,
                    color: distanceMeters < 0
                        ? Colors.grey
                        : withinRadius
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF44336)),
                const SizedBox(width: 4),
                Text(
                  distanceMeters < 0
                      ? 'ไม่สามารถระบุตำแหน่งได้'
                      : withinRadius
                          ? 'อยู่ในรัศมี ${distanceMeters.toStringAsFixed(1)} ม. จากถัง ✓'
                          : 'ห่างถัง ${distanceMeters.toStringAsFixed(1)} ม.',
                  style: TextStyle(
                    fontSize: 11,
                    color: distanceMeters < 0
                        ? Colors.grey
                        : withinRadius
                            ? const Color(0xFF388E3C)
                            : const Color(0xFFB71C1C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

  Widget _buildNavIcon(BuildContext context, IconData icon, String label,
      bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? const Color(0xFFD48EA1) : Colors.grey,
              size: 26),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFFD48EA1) : Colors.grey)),
        ],
      ),
    );
  }
}
