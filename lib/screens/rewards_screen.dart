import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'app_theme.dart';

enum RewardCategory { food, eco, activity }

extension RewardCategoryExt on RewardCategory {
  // ✅ ใช้ .tr() แทน hardcoded Thai
  String get label {
    switch (this) {
      case RewardCategory.food:     return 'rewards_cat_food'.tr();
      case RewardCategory.eco:      return 'rewards_cat_eco'.tr();
      case RewardCategory.activity: return 'rewards_cat_activity'.tr();
    }
  }

  static RewardCategory fromString(String? s) {
    switch (s) {
      case 'eco':      return RewardCategory.eco;
      case 'activity': return RewardCategory.activity;
      default:         return RewardCategory.food;
    }
  }
}

class RewardItem {
  final String id;
  final String name;
  final String nameEn;
  final RewardCategory category;
  final int pointsCost;
  final int totalQuantity;
  final int claimedQuantity;
  final String icon;

  RewardItem({
    required this.id, required this.name, this.nameEn = '',
    required this.category,
    required this.pointsCost, required this.totalQuantity,
    required this.claimedQuantity, required this.icon,
  });

  // ✅ คืนชื่อตามภาษา: ถ้าเป็น en และมี name_en ใช้ name_en, ไม่งั้นใช้ name (ไทย)
  String displayName(BuildContext context) {
    final isEn = context.locale.languageCode == 'en';
    if (isEn && nameEn.isNotEmpty) return nameEn;
    return name;
  }

  int get remaining => (totalQuantity - claimedQuantity).clamp(0, totalQuantity);
  double get progress => totalQuantity == 0 ? 0 : remaining / totalQuantity;
  bool get isLowStock => remaining <= (totalQuantity * 0.25).ceil() && remaining > 0;
  bool get isOutOfStock => remaining <= 0;

  IconData get iconData {
    switch (icon) {
      case 'coffee':    return Icons.local_cafe_outlined;
      case 'bag':       return Icons.shopping_bag_outlined;
      case 'tree':      return Icons.park_outlined;
      case 'print':     return Icons.print_outlined;
      case 'fuel':      return Icons.local_gas_station_outlined;
      case 'badge':     return Icons.military_tech_outlined;
      case 'parking':   return Icons.local_parking_outlined;
      case 'food':      return Icons.fastfood_outlined;
      case 'canteen':   return Icons.restaurant_menu_outlined;
      case 'book':      return Icons.menu_book_outlined;
      case 'shirt':     return Icons.checkroom_outlined;
      case 'seed':      return Icons.eco_outlined;
      case 'bottle':    return Icons.water_drop_outlined;
      case 'straw':     return Icons.local_drink_outlined;
      case 'workshop':  return Icons.handyman_outlined;
      case 'bike':      return Icons.pedal_bike_outlined;
      case 'cleanup':   return Icons.cleaning_services_outlined;
      case 'compost':   return Icons.compost_outlined;
      case 'refill':    return Icons.water_outlined;
      case 'certificate': return Icons.workspace_premium_outlined;
      case 'basket':    return Icons.shopping_basket_outlined;
      default:          return Icons.card_giftcard_outlined;
    }
  }

  factory RewardItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RewardItem(
      id: doc.id, name: d['name'] ?? '',
      nameEn: d['name_en'] ?? '',
      category: RewardCategoryExt.fromString(d['category']),
      pointsCost: (d['pointsCost'] as num?)?.toInt() ?? 0,
      totalQuantity: (d['totalQuantity'] as num?)?.toInt() ?? 0,
      claimedQuantity: (d['claimedQuantity'] as num?)?.toInt() ?? 0,
      icon: d['icon'] ?? 'gift',
    );
  }
}

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
    context.locale; // ✅ rebuild เมื่อภาษาเปลี่ยน
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('rewards'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          // ✅ ใช้ .tr() สำหรับ tab labels
          tabs: [
            Tab(text: 'rewards_tab_redeem'.tr()),
            Tab(text: 'rewards_tab_history'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RedeemTab(
            userId: userId,
            selectedCategory: _selectedCategory,
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
          ),
          _HistoryTab(userId: userId),
        ],
      ),
    );
  }
}

class _RedeemTab extends StatelessWidget {
  final String? userId;
  final RewardCategory? selectedCategory;
  final ValueChanged<RewardCategory?> onCategoryChanged;

  const _RedeemTab({required this.userId, required this.selectedCategory, required this.onCategoryChanged});

  Future<void> _redeem(BuildContext context, RewardItem reward, int myPoints) async {
    if (userId == null) return;

    if (myPoints < reward.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('rewards_not_enough_points'.tr())),
      );
      return;
    }
    if (reward.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('rewards_stock_empty'.tr())),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // ✅ ใช้ .tr()
        title: Text('rewards_confirm_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('rewards_confirm_body'.tr(
                namedArgs: {'name': reward.displayName(context), 'points': '${reward.pointsCost}'})),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'rewards_confirm_warning'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('rewards_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
            child: Text('rewards_confirm'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final code = _generateCouponCode();
    // ✅ เปลี่ยนจาก 30 วัน → 7 วัน ให้ตรงกับคำเตือน
    final expiry = DateTime.now().add(const Duration(days: 7));

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
        if (currentClaimed >= rewardTotal) throw Exception('rewards_stock_empty'.tr());
        if (currentPoints < reward.pointsCost) throw Exception('rewards_not_enough_points'.tr());
        txn.update(rewardRef, {'claimedQuantity': currentClaimed + 1});
        txn.update(userRef, {'points': currentPoints - reward.pointsCost});
        final redemptionRef = db.collection('redemptions').doc();
        txn.set(redemptionRef, {
          'userId': userId, 'rewardId': reward.id, 'rewardName': reward.name,
          'rewardNameEn': reward.nameEn,
          'pointsCost': reward.pointsCost, 'code': code,
          'createdAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(expiry), 'used': false,
        });
      });
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CouponDetailScreen(rewardName: reward.name, code: code, expiry: expiry),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('rewards_error'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  // ✅ โค้ดคูปอง 6 ตัวอักษร (ตัด prefix "BINSORT-" ออก)
  String _generateCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        int myPoints = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          myPoints = ((userSnap.data!.data() as Map<String, dynamic>)['points'] as num?)?.toInt() ?? 0;
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
                    Text('redeem_rewards'.tr(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _CategoryChips(selected: selectedCategory, onChanged: onCategoryChanged),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rewards').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kPrimaryGreen)));
                }
                var rewards = snap.data!.docs.map((d) => RewardItem.fromFirestore(d)).toList();
                final Map<String, RewardItem> merged = {};
                for (final r in rewards) {
                  if (merged.containsKey(r.name)) {
                    final e = merged[r.name]!;
                    merged[r.name] = RewardItem(
                      id: e.id, name: e.name, nameEn: e.nameEn,
                      category: e.category,
                      pointsCost: e.pointsCost,
                      totalQuantity: e.totalQuantity + r.totalQuantity,
                      claimedQuantity: e.claimedQuantity + r.claimedQuantity,
                      icon: e.icon,
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
                  final ac = myPoints >= a.pointsCost && !a.isOutOfStock;
                  final bc = myPoints >= b.pointsCost && !b.isOutOfStock;
                  if (ac != bc) return ac ? -1 : 1;
                  return a.pointsCost.compareTo(b.pointsCost);
                });
                if (rewards.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(child: Text('rewards_no_in_category'.tr(),
                        style: const TextStyle(color: Colors.grey))),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _RewardCard(
                        reward: rewards[i], myPoints: myPoints,
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

class _PointsHeader extends StatelessWidget {
  final int points;
  const _PointsHeader({required this.points});

  // ✅ ใช้ .tr() สำหรับ level names
  String _levelName(int points) {
    if (points >= 2000) return 'rewards_level_god'.tr();
    if (points >= 1000) return 'rewards_level_pro'.tr();
    if (points >= 300)  return 'rewards_level_recycler'.tr();
    return 'rewards_level_beginner'.tr();
  }

  int _nextThreshold(int points) {
    if (points < 300)  return 300;
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kLightGreen, kPrimaryGreen, kDarkGreen],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: kPrimaryGreen.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('your_points'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text("${NumberFormat('#,###').format(points)} ${'points'.tr()}",
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${'rewards_level_label'.tr()} • ${_levelName(points)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 44),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress, minHeight: 8,
              backgroundColor: Colors.white38,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'rewards_next_level'.tr(
                namedArgs: {'points': NumberFormat('#,###').format(nextThreshold)}),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

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
          // ✅ ใช้ .tr() สำหรับ "ทั้งหมด"
          final label = c == null ? 'rewards_cat_all'.tr() : c.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onChanged(c),
              selectedColor: kPrimaryGreen,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? kPrimaryGreen : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

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
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccentGreen.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
                child: Icon(reward.iconData, color: kDarkGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reward.displayName(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("${NumberFormat('#,###').format(reward.pointsCost)} ${'points'.tr()}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: canRedeem ? onRedeem : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canRedeem ? kPrimaryGreen : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  // ✅ ใช้ .tr() สำหรับ button text
                  child: Text(
                    reward.isOutOfStock ? 'rewards_out_of_stock'.tr() : 'rewards_redeem_btn'.tr(),
                    style: TextStyle(
                        color: canRedeem ? Colors.white : Colors.grey.shade600, fontSize: 13),
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
                    value: reward.progress, minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      reward.isOutOfStock ? Colors.grey : reward.isLowStock ? Colors.orange : kPrimaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (reward.isLowStock)
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
              // ✅ ใช้ .tr() สำหรับ "เหลือ X/Y"
              Text(
                ' ${'rewards_remaining'.tr(namedArgs: {'remaining': '${reward.remaining}', 'total': '${reward.totalQuantity}'})}',
                style: TextStyle(
                    fontSize: 11,
                    color: reward.isLowStock ? Colors.orange : Colors.grey,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final String? userId;
  const _HistoryTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Center(child: Text('rewards_login_required'.tr()));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        int myPoints = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          myPoints = ((userSnap.data!.data() as Map<String, dynamic>)['points'] as num?)?.toInt() ?? 0;
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('redemptions')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
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
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ ใช้ .tr()
                      Text('rewards_history_total'.tr(namedArgs: {'count': '${docs.length}'}),
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(
                        'rewards_remaining_points'.tr(namedArgs: {'points': NumberFormat('#,###').format(myPoints)}),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryGreen),
                      ),
                    ],
                  ),
                ),
                if (docs.isEmpty)
                  Expanded(child: Center(child: Text('rewards_no_history'.tr(),
                      style: const TextStyle(color: Colors.grey))))
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final rewardNameTh = d['rewardName'] ?? '-';
                        final rewardNameEn = d['rewardNameEn'] ?? '';
                        final rewardName = (context.locale.languageCode == 'en' && rewardNameEn.toString().isNotEmpty)
                            ? rewardNameEn
                            : rewardNameTh;
                        final pointsCost = (d['pointsCost'] as num?)?.toInt() ?? 0;
                        final code = d['code'] ?? '';
                        final used = d['used'] == true;
                        final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
                        final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
                        final dateStr = createdAt != null
                            ? (context.locale.languageCode == 'th'
                                ? DateFormat('dd MMMM yyyy • HH:mm น.', 'th').format(createdAt)
                                : DateFormat('MMMM dd, yyyy • HH:mm', 'en').format(createdAt))
                            : '';
                        final expiryStr = expiresAt != null
                            ? DateFormat('dd/MM/yyyy').format(expiresAt)
                            : '';
                        final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

                        return GestureDetector(
                          onTap: expiresAt != null
                              ? () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => CouponDetailScreen(
                                        rewardName: rewardName, code: code, expiry: expiresAt),
                                  ))
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: kPrimaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.card_giftcard_rounded, color: kPrimaryGreen, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(rewardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(code, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if (expiryStr.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '${'coupon_expires_label'.tr()} $expiryStr',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: used ? Colors.grey : isExpired ? Colors.red.shade400 : Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('-$pointsCost ${'points'.tr()}',
                                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: used ? Colors.grey.shade300 : isExpired ? Colors.red.shade100 : kPrimaryGreen.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    // ✅ ใช้ .tr() สำหรับ status
                                    child: Text(
                                      used ? 'coupon_completed'.tr() : isExpired ? 'coupon_expired'.tr() : 'coupon_pending_approval'.tr(),
                                      style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w600,
                                          color: used ? Colors.grey.shade700 : isExpired ? Colors.red.shade700 : kPrimaryGreen),
                                    ),
                                  ),
                                ]),
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

class CouponDetailScreen extends StatelessWidget {
  final String rewardName;
  final String code;
  final DateTime expiry;
  final bool initialUsed;

  const CouponDetailScreen({
    super.key, required this.rewardName, required this.code,
    required this.expiry, this.initialUsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = expiry.isBefore(DateTime.now());
    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('coupon_title'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ ฟัง Firestore แบบ real-time เพื่อรับสถานะ "used" ที่เจ้าหน้าที่อัปเดตผ่าน Firebase Console
        stream: FirebaseFirestore.instance
            .collection('redemptions')
            .where('code', isEqualTo: code)
            .limit(1)
            .snapshots(),
        builder: (context, snap) {
          bool isUsed = initialUsed;
          if (snap.hasData && snap.data!.docs.isNotEmpty) {
            final d = snap.data!.docs.first.data() as Map<String, dynamic>;
            isUsed = d['used'] == true;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: isUsed
                        ? null
                        : isExpired
                            ? null
                            : const LinearGradient(colors: [kLightGreen, kPrimaryGreen]),
                    color: isUsed ? kDarkGreen : isExpired ? Colors.red.shade300 : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(children: [
                    Icon(isUsed ? Icons.check_circle_outline : Icons.local_cafe_outlined,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(rewardName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      isUsed ? 'coupon_completed'.tr() : isExpired ? 'coupon_expired'.tr() : 'coupon_redeemed'.tr(),
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('coupon_code_label'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.grey.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isUsed ? Colors.grey.shade300 : kPrimaryGreen, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(code,
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4,
                                color: isUsed ? Colors.grey : Colors.black),
                            textAlign: TextAlign.center),
                      ),
                      if (!isUsed) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('coupon_copied'.tr()), duration: const Duration(seconds: 1)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: kPrimaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.copy_rounded, color: kPrimaryGreen, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft,
                    child: Text('coupon_how_to'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                _StepRow(text: 'coupon_step_simple'.tr()),
                const Spacer(),
                Text('coupon_expires'.tr(namedArgs: {'date': DateFormat('dd/MM/yyyy').format(expiry)}),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                // ✅ ไม่มีปุ่มให้ลูกค้ากดยืนยันเองแล้ว — แสดงสถานะอย่างเดียว
                if (isUsed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kPrimaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kPrimaryGreen.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: kPrimaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text('coupon_completed'.tr(),
                            style: const TextStyle(color: kDarkGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else if (isExpired)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text('coupon_expired'.tr(),
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade400),
                        ),
                        const SizedBox(width: 10),
                        Text('coupon_pending_approval'.tr(),
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kPrimaryGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text('coupon_back'.tr(), style: const TextStyle(color: kPrimaryGreen)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String text;
  const _StepRow({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
  );
}