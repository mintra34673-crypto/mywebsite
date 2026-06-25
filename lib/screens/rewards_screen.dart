import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// ── หมวดหมู่รางวัล ─────────────────────────────────────────────────────────
enum RewardCategory { food, eco, activity }

extension RewardCategoryExt on RewardCategory {
  String get label {
    switch (this) {
      case RewardCategory.food:
        return 'อาหาร';
      case RewardCategory.eco:
        return 'Eco';
      case RewardCategory.activity:
        return 'กิจกรรม';
    }
  }

  static RewardCategory fromString(String? s) {
    switch (s) {
      case 'eco':
        return RewardCategory.eco;
      case 'activity':
        return RewardCategory.activity;
      default:
        return RewardCategory.food;
    }
  }
}

// ── Model รางวัล ───────────────────────────────────────────────────────────
class RewardItem {
  final String id;
  final String name;
  final RewardCategory category;
  final int pointsCost;
  final int totalQuantity;
  final int claimedQuantity;
  final String icon;

  RewardItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pointsCost,
    required this.totalQuantity,
    required this.claimedQuantity,
    required this.icon,
  });

  int get remaining => (totalQuantity - claimedQuantity).clamp(0, totalQuantity);
  double get progress => totalQuantity == 0 ? 0 : remaining / totalQuantity;
  bool get isLowStock => remaining <= (totalQuantity * 0.25).ceil() && remaining > 0;
  bool get isOutOfStock => remaining <= 0;

  IconData get iconData {
    switch (icon) {
      case 'coffee':
        return Icons.local_cafe_outlined;
      case 'bag':
        return Icons.shopping_bag_outlined;
      case 'tree':
        return Icons.park_outlined;
      case 'print':
        return Icons.print_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'badge':
        return Icons.military_tech_outlined;
      case 'parking':
        return Icons.local_parking_outlined;
      case 'food':
        return Icons.fastfood_outlined;
      case 'canteen':
        return Icons.restaurant_menu_outlined;
      case 'book':
        return Icons.menu_book_outlined;
      case 'shirt':
        return Icons.checkroom_outlined;
      case 'seed':
        return Icons.eco_outlined;
      case 'bottle':
        return Icons.water_drop_outlined;
      case 'straw':
        return Icons.local_drink_outlined;
      case 'workshop':
        return Icons.handyman_outlined;
      case 'bike':
        return Icons.pedal_bike_outlined;
      case 'cleanup':
        return Icons.cleaning_services_outlined;
      case 'compost':
        return Icons.compost_outlined;
      case 'refill':
        return Icons.water_outlined;
      case 'certificate':
        return Icons.workspace_premium_outlined;
      case 'basket':
        return Icons.shopping_basket_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  factory RewardItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RewardItem(
      id: doc.id,
      name: d['name'] ?? '',
      category: RewardCategoryExt.fromString(d['category']),
      pointsCost: (d['pointsCost'] as num?)?.toInt() ?? 0,
      totalQuantity: (d['totalQuantity'] as num?)?.toInt() ?? 0,
      claimedQuantity: (d['claimedQuantity'] as num?)?.toInt() ?? 0,
      icon: d['icon'] ?? 'gift',
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RewardCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

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
          'rewards'.tr(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'แลกรางวัล'),
            Tab(text: 'ประวัติการแลก'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RedeemTab(userId: userId, selectedCategory: _selectedCategory, onCategoryChanged: (c) => setState(() => _selectedCategory = c)),
          _HistoryTab(userId: userId),
        ],
      ),
    );
  }
}

// ── Tab 1: แลกรางวัล ──────────────────────────────────────────────────────
class _RedeemTab extends StatelessWidget {
  final String? userId;
  final RewardCategory? selectedCategory;
  final ValueChanged<RewardCategory?> onCategoryChanged;

  const _RedeemTab({
    required this.userId,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  Future<void> _redeem(BuildContext context, RewardItem reward, int myPoints) async {
    if (userId == null) return;

    if (myPoints < reward.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แต้มของคุณไม่เพียงพอ')),
      );
      return;
    }
    if (reward.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สิทธิ์หมดแล้ว')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการแลก'),
        content: Text('แลก "${reward.name}" ด้วย ${reward.pointsCost} แต้ม?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirm != true) return;

    final code = _generateCouponCode();
    final expiry = DateTime.now().add(const Duration(days: 30));

    try {
      final db = FirebaseFirestore.instance;
      await db.runTransaction((txn) async {
        final rewardRef = db.collection('rewards').doc(reward.id);
        final userRef = db.collection('users').doc(userId);

        final rewardSnap = await txn.get(rewardRef);
        final userSnap = await txn.get(userRef);

        final rewardTotal = (rewardSnap.data()?['totalQuantity'] as num?)?.toInt() ?? reward.totalQuantity;
        final currentClaimed = (rewardSnap.data()?['claimedQuantity'] as num?)?.toInt() ?? 0;
        final currentPoints = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;

        if (currentClaimed >= rewardTotal) {
          throw Exception('สิทธิ์หมดแล้ว');
        }
        if (currentPoints < reward.pointsCost) {
          throw Exception('แต้มไม่เพียงพอ');
        }

        txn.update(rewardRef, {'claimedQuantity': currentClaimed + 1});
        txn.update(userRef, {'points': currentPoints - reward.pointsCost});

        final redemptionRef = db.collection('redemptions').doc();
        txn.set(redemptionRef, {
          'userId': userId,
          'rewardId': reward.id,
          'rewardName': reward.name,
          'pointsCost': reward.pointsCost,
          'code': code,
          'createdAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(expiry),
          'used': false,
        });
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CouponDetailScreen(
              rewardName: reward.name,
              code: code,
              expiry: expiry,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  String _generateCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'CLEANCM-$code';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        int myPoints = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          final d = userSnap.data!.data() as Map<String, dynamic>;
          myPoints = (d['points'] as num?)?.toInt() ?? 0;
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PointsHeader(points: myPoints),
                    const SizedBox(height: 24),
                    Text(
                      'redeem_rewards'.tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _CategoryChips(
                      selected: selectedCategory,
                      onChanged: onCategoryChanged,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rewards').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text('โหลดข้อมูลไม่ได้: ${snap.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                var rewards = snap.data!.docs.map((d) => RewardItem.fromFirestore(d)).toList();

                // รวมรายการที่ชื่อซ้ำกันให้เหลือใบเดียว (รวมจำนวนคงเหลือ/ทั้งหมด)
                final Map<String, RewardItem> merged = {};
                for (final r in rewards) {
                  if (merged.containsKey(r.name)) {
                    final existing = merged[r.name]!;
                    merged[r.name] = RewardItem(
                      id: existing.id,
                      name: existing.name,
                      category: existing.category,
                      pointsCost: existing.pointsCost,
                      totalQuantity: existing.totalQuantity + r.totalQuantity,
                      claimedQuantity: existing.claimedQuantity + r.claimedQuantity,
                      icon: existing.icon,
                    );
                  } else {
                    merged[r.name] = r;
                  }
                }
                rewards = merged.values.toList();

                if (selectedCategory != null) {
                  rewards = rewards.where((r) => r.category == selectedCategory).toList();
                }

                rewards.sort((a, b) {
                  final aCanRedeem = myPoints >= a.pointsCost && !a.isOutOfStock;
                  final bCanRedeem = myPoints >= b.pointsCost && !b.isOutOfStock;
                  if (aCanRedeem != bCanRedeem) return aCanRedeem ? -1 : 1;
                  return a.pointsCost.compareTo(b.pointsCost);
                });

                if (rewards.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('ยังไม่มีรางวัลในหมวดนี้', style: TextStyle(color: Colors.grey))),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _RewardCard(
                        reward: rewards[i],
                        myPoints: myPoints,
                        onRedeem: () => _redeem(context, rewards[i], myPoints),
                      ),
                      childCount: rewards.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }
}

// ── การ์ดแต้มสะสม ────────────────────────────────────────────────────────
class _PointsHeader extends StatelessWidget {
  final int points;
  const _PointsHeader({required this.points});

  String _levelName(int points) {
    if (points >= 2000) return 'นักรีไซเคิลระดับเทพ';
    if (points >= 1000) return 'นักรีไซเคิลมือโปร';
    if (points >= 300) return 'นักรีไซเคิล';
    return 'มือใหม่';
  }

  int _nextThreshold(int points) {
    if (points < 300) return 300;
    if (points < 1000) return 1000;
    if (points < 2000) return 2000;
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final nextThreshold = _nextThreshold(points);
    final progress = (points / nextThreshold).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC5E1A5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('your_points'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    "${NumberFormat('#,###').format(points)} ${'points'.tr()}",
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text('ระดับ • ${_levelName(points)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 44),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white38,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ถึงระดับถัดไป ${NumberFormat('#,###').format(nextThreshold)} แต้ม',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Chips หมวดหมู่ ───────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final RewardCategory? selected;
  final ValueChanged<RewardCategory?> onChanged;
  const _CategoryChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <RewardCategory?>[null, RewardCategory.food, RewardCategory.eco, RewardCategory.activity];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((c) {
          final isSelected = selected == c;
          final label = c == null ? 'ทั้งหมด' : c.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onChanged(c),
              selectedColor: const Color(0xFF4CAF50),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── การ์ดรางวัลแต่ละชิ้น ──────────────────────────────────────────────────
class _RewardCard extends StatelessWidget {
  final RewardItem reward;
  final int myPoints;
  final VoidCallback onRedeem;

  const _RewardCard({required this.reward, required this.myPoints, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final canRedeem = myPoints >= reward.pointsCost && !reward.isOutOfStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Icon(reward.iconData, color: const Color(0xFFD4B996), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      "${NumberFormat('#,###').format(reward.pointsCost)} ${'points'.tr()}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: canRedeem ? onRedeem : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canRedeem ? const Color(0xFF4CAF50) : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    reward.isOutOfStock ? 'หมด' : 'แลก',
                    style: TextStyle(color: canRedeem ? Colors.white : Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: reward.progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      reward.isOutOfStock
                          ? Colors.grey
                          : reward.isLowStock
                              ? Colors.orange
                              : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (reward.isLowStock)
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
              Text(
                ' เหลือ ${reward.remaining}/${reward.totalQuantity}',
                style: TextStyle(
                  fontSize: 11,
                  color: reward.isLowStock ? Colors.orange : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: ประวัติการแลกรางวัล ────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final String? userId;
  const _HistoryTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบ'));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        int myPoints = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          final d = userSnap.data!.data() as Map<String, dynamic>;
          myPoints = (d['points'] as num?)?.toInt() ?? 0;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('redemptions')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('ไม่สามารถโหลดข้อมูลได้'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs.toList()
              ..sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (ta == null || tb == null) return 0;
                return tb.compareTo(ta);
              });

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('แลกไปทั้งหมด ${docs.length} รายการ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(
                        'แต้มคงเหลือ ${NumberFormat('#,###').format(myPoints)} แต้ม',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                      ),
                    ],
                  ),
                ),
                if (docs.isEmpty)
                  const Expanded(
                    child: Center(child: Text('ยังไม่มีประวัติการแลกรางวัล', style: TextStyle(color: Colors.grey))),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final rewardName = d['rewardName'] ?? 'รางวัล';
                        final pointsCost = (d['pointsCost'] as num?)?.toInt() ?? 0;
                        final code = d['code'] ?? '';
                        final used = d['used'] == true;
                        final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
                        final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
                        final dateStr = createdAt != null
                            ? DateFormat('dd MMMM yyyy • HH:mm น.', 'th').format(createdAt)
                            : '';
                        final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

                        return GestureDetector(
                          onTap: expiresAt != null
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CouponDetailScreen(
                                        rewardName: rewardName,
                                        code: code,
                                        expiry: expiresAt,
                                      ),
                                    ),
                                  )
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF4CAF50), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(rewardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(code, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('-$pointsCost แต้ม', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: used
                                            ? Colors.grey.shade300
                                            : isExpired
                                                ? Colors.red.shade100
                                                : const Color(0xFF4CAF50).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        used ? 'ใช้แล้ว' : isExpired ? 'หมดอายุ' : 'ใช้ได้',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: used
                                              ? Colors.grey.shade700
                                              : isExpired
                                                  ? Colors.red.shade700
                                                  : const Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── หน้าแสดงคูปองหลังแลกสำเร็จ ──────────────────────────────────────────────
class CouponDetailScreen extends StatelessWidget {
  final String rewardName;
  final String code;
  final DateTime expiry;

  const CouponDetailScreen({
    super.key,
    required this.rewardName,
    required this.code,
    required this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('คูปองรางวัล', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFC5E1A5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_cafe_outlined, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(rewardName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('แลกสำเร็จ', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('รหัสประกอบการแลก', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      code,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('คัดลอกรหัสคูปองแล้ว'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.copy_rounded, color: Color(0xFF4CAF50), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'วิธีใช้สิทธิ์',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const _StepRow(text: '1. แสดงหน้าจอนี้ที่ร้านค้า'),
            const _StepRow(text: '2. แจ้งพนักงานว่าต้องการใช้ CleanCM Coupon'),
            const _StepRow(text: '3. พนักงานสแกน Code เพื่อยืนยัน'),
            const _StepRow(text: '4. รับสิทธิ์ทันทีเมื่อยืนยันแล้ว'),
            const Spacer(),
            Text(
              'หมดอายุ ${DateFormat('dd/MM/yyyy').format(expiry)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('รับทราบ ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String text;
  const _StepRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }
}
