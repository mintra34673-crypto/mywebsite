import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
import 'activity_screen.dart';
import 'my_qr_code_screen.dart';
import 'ranking_screen.dart';
import 'profile_screen.dart';

class WasteGuideScreen extends StatefulWidget {
  const WasteGuideScreen({super.key});

  @override
  State<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

class _WasteGuideScreenState extends State<WasteGuideScreen> {
  int _selectedBin = 0; // 0=ทั้งหมด 1=น้ำเงิน 2=เขียว 3=เหลือง 4=แดง
  int _expandedIndex = -1;

  final List<Map<String, dynamic>> _bins = [
    {
      'label': 'ทั้งหมด',
      'color': Colors.grey,
      'icon': Icons.delete_outline,
    },
    {
      'label': 'น้ำเงิน',
      'color': const Color(0xFF1565C0),
      'icon': Icons.recycling,
      'desc': 'ขยะรีไซเคิล — วัสดุที่สามารถนำกลับมาใช้ใหม่ได้',
    },
    {
      'label': 'เขียว',
      'color': const Color(0xFF2E7D32),
      'icon': Icons.eco,
      'desc': 'ขยะอินทรีย์ — เศษอาหารและวัสดุที่ย่อยสลายได้',
    },
    {
      'label': 'เหลือง',
      'color': const Color(0xFFF9A825),
      'icon': Icons.delete_outline,
      'desc': 'ขยะทั่วไป — ขยะที่ไม่สามารถรีไซเคิลหรือย่อยสลายได้',
    },
    {
      'label': 'แดง',
      'color': const Color(0xFFB71C1C),
      'icon': Icons.warning_amber_rounded,
      'desc': 'ขยะอันตราย — วัสดุที่มีสารพิษหรืออันตราย',
    },
  ];

  final List<Map<String, dynamic>> _wasteItems = [
    // ── รีไซเคิล (น้ำเงิน) ──────────────────────────────────────────────────
    {
      'bin': 1,
      'name': 'พลาสติก',
      'sub': 'PET, PP, HDPE, LDPE',
      'icon': Icons.local_drink_outlined,
      'bgColor': const Color(0xFFE3F2FD),
      'examples': ['ขวดน้ำ PET', 'ถุงพลาสติก PP', 'กล่องอาหาร HDPE', 'หลอดดูด'],
      'doList': [
        'ล้างให้สะอาดก่อนทิ้ง',
        'แยกฝาออกจากขวด',
        'บีบให้แบนเพื่อประหยัดพื้นที่',
        'ดูสัญลักษณ์รีไซเคิลที่ก้นภาชนะ',
      ],
      'dontList': [
        'ไม่ทิ้งพลาสติกปนกับขยะเปียก',
        'ไม่รีไซเคิลโฟม EPS',
        'ไม่ทิ้งถุงพลาสติกในถังรีไซเคิล',
      ],
      'note': 'พลาสติก 1 ตัน รีไซเคิลได้ประหยัดน้ำมัน 5,774 ลิตร',
    },
    {
      'bin': 1,
      'name': 'กระดาษ',
      'sub': 'กระดาษทุกชนิดที่แห้งสะอาด',
      'icon': Icons.auto_stories_outlined,
      'bgColor': const Color(0xFFE3F2FD),
      'examples': ['หนังสือพิมพ์', 'กล่องกระดาษ', 'นิตยสาร', 'กระดาษ A4'],
      'doList': [
        'พับหรือม้วนให้เรียบร้อย',
        'แยกสันเล่มออกก่อนรีไซเคิล',
        'มัดรวมกันเป็นกอง',
      ],
      'dontList': [
        'ไม่ทิ้งกระดาษเปียกหรือมันวาว',
        'ไม่รีไซเคิลกระดาษทิชชู่ที่ใช้แล้ว',
        'ไม่ทิ้งกล่องอาหารที่มีคราบมัน',
      ],
      'note': 'รีไซเคิลกระดาษ 1 ตัน = ช่วยต้นไม้ 17 ต้น',
    },
    {
      'bin': 1,
      'name': 'โลหะ',
      'sub': 'เหล็ก อะลูมิเนียม ทองแดง',
      'icon': Icons.inventory_2_outlined,
      'bgColor': const Color(0xFFE3F2FD),
      'examples': ['กระป๋องน้ำอัดลม', 'กระป๋องอาหาร', 'ฝาขวด', 'ลวด'],
      'doList': [
        'ล้างให้สะอาดก่อนทิ้ง',
        'บีบให้แบนเพื่อประหยัดพื้นที่',
        'แยกโลหะจากวัสดุอื่น',
      ],
      'dontList': [
        'ไม่ทิ้งกระป๋องที่มีของเหลวเหลืออยู่',
        'ไม่รวมกับแก้วหรือพลาสติก',
      ],
      'note': 'รีไซเคิลอะลูมิเนียม 1 กระป๋อง ประหยัดพลังงานได้ 95%',
    },
    {
      'bin': 1,
      'name': 'แก้ว',
      'sub': 'ขวดแก้ว กระจก',
      'icon': Icons.wine_bar_outlined,
      'bgColor': const Color(0xFFE3F2FD),
      'examples': ['ขวดน้ำแก้ว', 'ขวดซอส', 'แจกัน', 'กระจกหน้าต่าง'],
      'doList': [
        'ล้างให้สะอาดก่อนทิ้ง',
        'แยกฝาโลหะออก',
        'ระวังขอบแหลมคม',
      ],
      'dontList': [
        'ไม่ทิ้งหลอดไฟหรือกระจกรถในถังนี้',
        'ไม่ทุบแก้วให้แตกก่อนทิ้ง',
      ],
      'note': 'แก้วรีไซเคิลได้ 100% โดยไม่สูญเสียคุณภาพ',
    },

    // ── อินทรีย์ (เขียว) ─────────────────────────────────────────────────────
    {
      'bin': 2,
      'name': 'เศษอาหาร',
      'sub': 'อาหารเหลือ เปลือกผลไม้',
      'icon': Icons.restaurant_outlined,
      'bgColor': const Color(0xFFE8F5E9),
      'examples': ['เศษข้าว', 'เปลือกผลไม้', 'กากกาแฟ', 'เปลือกไข่'],
      'doList': [
        'สะเด็ดน้ำให้แห้งก่อนทิ้ง',
        'ใช้ถุงย่อยสลายได้',
        'แยกจากขยะประเภทอื่น',
      ],
      'dontList': [
        'ไม่ทิ้งกระดูกสัตว์ขนาดใหญ่',
        'ไม่ทิ้งน้ำมันปรุงอาหาร',
      ],
      'note': 'เศษอาหารทำปุ๋ยหมักได้ภายใน 1-3 เดือน',
    },
    {
      'bin': 2,
      'name': 'เศษพืช',
      'sub': 'ใบไม้ กิ่งไม้ หญ้า',
      'icon': Icons.eco_outlined,
      'bgColor': const Color(0xFFE8F5E9),
      'examples': ['ใบไม้แห้ง', 'กิ่งไม้เล็ก', 'หญ้าตัด', 'ดอกไม้เหี่ยว'],
      'doList': [
        'ตัดให้เป็นชิ้นเล็กก่อนทิ้ง',
        'ผสมกับเศษอาหารได้',
      ],
      'dontList': [
        'ไม่ทิ้งกิ่งไม้ขนาดใหญ่',
        'ไม่ทิ้งพืชที่มียาฆ่าแมลง',
      ],
      'note': 'ใบไม้แห้งช่วยเพิ่มอากาศในกองปุ๋ยหมัก',
    },

    // ── ทั่วไป (เหลือง) ──────────────────────────────────────────────────────
    {
      'bin': 3,
      'name': 'ขยะทั่วไป',
      'sub': 'ขยะที่ไม่สามารถรีไซเคิลได้',
      'icon': Icons.delete_outline,
      'bgColor': const Color(0xFFFFFDE7),
      'examples': ['โฟม EPS', 'ถุงขนม', 'ผ้าอ้อม', 'บุหรี่'],
      'doList': [
        'ใส่ถุงให้มิดชิดก่อนทิ้ง',
        'ไม่ทิ้งของมีคม',
      ],
      'dontList': [
        'ไม่ทิ้งขยะอันตรายในถังนี้',
        'ไม่ทิ้งขวดแก้วแตก',
      ],
      'note': 'ลดขยะทั่วไปด้วยการเลือกซื้อสินค้าที่บรรจุภัณฑ์รีไซเคิลได้',
    },

    // ── อันตราย (แดง) ────────────────────────────────────────────────────────
    {
      'bin': 4,
      'name': 'แบตเตอรี่',
      'sub': 'แบตเตอรี่ทุกชนิด',
      'icon': Icons.battery_alert_outlined,
      'bgColor': const Color(0xFFFFEBEE),
      'examples': ['แบตมือถือ', 'ถ่านไฟฉาย', 'แบตรถ', 'แบต laptop'],
      'doList': [
        'นำส่งจุดรับแบตเตอรี่เก่า',
        'เก็บในที่แห้งก่อนนำส่ง',
        'ห่อด้วยเทปที่ขั้วไฟฟ้า',
      ],
      'dontList': [
        'ไม่ทิ้งในถังขยะทั่วไป',
        'ไม่เผาหรือแช่น้ำ',
        'ไม่แกะหรือเจาะแบตเตอรี่',
      ],
      'note': 'แบตเตอรี่ 1 ก้อนปนเปื้อนน้ำได้ถึง 400 ลิตร',
    },
    {
      'bin': 4,
      'name': 'หลอดไฟ',
      'sub': 'หลอด LED, หลอดฟลูออเรสเซนต์',
      'icon': Icons.lightbulb_outline,
      'bgColor': const Color(0xFFFFEBEE),
      'examples': ['หลอด LED', 'หลอดนีออน', 'หลอดประหยัดไฟ', 'หลอดฮาโลเจน'],
      'doList': [
        'ห่อด้วยกระดาษหนังสือพิมพ์',
        'นำส่งศูนย์รับหลอดไฟเก่า',
      ],
      'dontList': [
        'ไม่ทุบหรือทำให้แตก',
        'ไม่ทิ้งในถังขยะทั่วไป',
      ],
      'note': 'หลอดฟลูออเรสเซนต์มีสารปรอท ต้องทิ้งอย่างถูกวิธี',
    },
    {
      'bin': 4,
      'name': 'สารเคมี',
      'sub': 'สี ยาฆ่าแมลง ตัวทำละลาย',
      'icon': Icons.warning_amber_outlined,
      'bgColor': const Color(0xFFFFEBEE),
      'examples': ['สีทาบ้าน', 'ยาฆ่าแมลง', 'ทินเนอร์', 'น้ำยาล้างห้องน้ำ'],
      'doList': [
        'เก็บในภาชนะปิดสนิท',
        'นำส่งศูนย์รับขยะอันตราย',
        'อ่านฉลากวิธีทิ้งที่ถูกต้อง',
      ],
      'dontList': [
        'ไม่เทลงท่อน้ำทิ้ง',
        'ไม่เผาในที่โล่ง',
        'ไม่ผสมสารเคมีต่างชนิด',
      ],
      'note': '1-5 ชาวบ้าน, 5 PET โรงงาน ประกัน PP-3 ปี',
    },
  ];

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedBin == 0) return _wasteItems;
    return _wasteItems.where((w) => w['bin'] == _selectedBin).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'waste_guide'.tr(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── ถังขยะ 4 สี header ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🗑 ถังขยะ 4 สี — ทิ้งให้ถูกถัง',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(4, (i) {
                    final bin = _bins[i + 1];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedBin = _selectedBin == i + 1 ? 0 : i + 1;
                          _expandedIndex = -1;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedBin == i + 1
                                ? (bin['color'] as Color)
                                : (bin['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: bin['color'] as Color,
                              width: _selectedBin == i + 1 ? 0 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                bin['icon'] as IconData,
                                color: _selectedBin == i + 1
                                    ? Colors.white
                                    : bin['color'] as Color,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bin['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedBin == i + 1
                                      ? Colors.white
                                      : bin['color'] as Color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (_selectedBin > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_bins[_selectedBin]['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(_bins[_selectedBin]['icon'] as IconData,
                            color: _bins[_selectedBin]['color'] as Color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bins[_selectedBin]['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: _bins[_selectedBin]['color'] as Color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // ── รายการขยะ ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isExpanded = _expandedIndex == index;
                final binColor = _bins[item['bin'] as int]['color'] as Color;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? item['bgColor'] as Color
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpanded ? binColor.withOpacity(0.3) : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: binColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData, color: binColor, size: 24),
                        ),
                        title: Text(
                          item['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          item['sub'] as String,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: binColor,
                        ),
                        onTap: () => setState(() {
                          _expandedIndex = isExpanded ? -1 : index;
                        }),
                      ),
                      if (isExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              // ตัวอย่าง
                              _sectionTitle('📦 ตัวอย่าง', binColor),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: (item['examples'] as List).cast<String>().map((e) =>
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: binColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: binColor.withOpacity(0.3)),
                                    ),
                                    child: Text(e, style: TextStyle(fontSize: 12, color: binColor)),
                                  ),
                                ).toList(),
                              ),
                              const SizedBox(height: 12),

                              // วิธีทิ้ง
                              _sectionTitle('✅ วิธีทิ้งที่ถูกต้อง', const Color(0xFF2E7D32)),
                              const SizedBox(height: 6),
                              ...(item['doList'] as List).cast<String>().map((d) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          color: Color(0xFF2E7D32), size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ข้อห้าม
                              _sectionTitle('❌ ข้อควรระวัง', const Color(0xFFB71C1C)),
                              const SizedBox(height: 6),
                              ...(item['dontList'] as List).cast<String>().map((d) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.cancel_outlined,
                                          color: Color(0xFFB71C1C), size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // หมายเหตุ
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: binColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline, color: binColor, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item['note'] as String,
                                        style: TextStyle(fontSize: 12, color: binColor, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
              _navIcon(Icons.home, 'home'.tr(), false,
                  onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false)),
              _navIcon(Icons.grid_view_rounded, 'activity'.tr(), false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ActivityScreen()))),
              const SizedBox(width: 40),
              _navIcon(Icons.leaderboard_outlined, 'ranking'.tr(), false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RankingScreen()))),
              _navIcon(Icons.person_outline, 'profile'.tr(), false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _navIcon(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFD48EA1) : Colors.grey, size: 26),
          Text(label, style: TextStyle(
              fontSize: 10, color: isActive ? const Color(0xFFD48EA1) : Colors.grey)),
        ],
      ),
    );
  }
}
