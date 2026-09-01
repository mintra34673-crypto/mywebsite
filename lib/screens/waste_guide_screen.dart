import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class WasteGuideScreen extends StatefulWidget {
  const WasteGuideScreen({super.key});

  @override
  State<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

class _WasteGuideScreenState extends State<WasteGuideScreen> {
  int _selectedBin = 0;
  int _expandedIndex = -1;

  List<Map<String, dynamic>> get _bins => [
    {'label': 'wg_bin_all'.tr(), 'color': Colors.grey, 'icon': Icons.delete_outline},
    {'label': 'wg_bin_recycle'.tr(), 'color': const Color(0xFFF9A825), 'icon': Icons.recycling, 'desc': 'wg_bin_recycle_desc'.tr()},
    {'label': 'wg_bin_organic'.tr(), 'color': const Color(0xFF2E7D32), 'icon': Icons.eco, 'desc': 'wg_bin_organic_desc'.tr()},
    {'label': 'wg_bin_general'.tr(), 'color': const Color(0xFF1565C0), 'icon': Icons.delete_outline, 'desc': 'wg_bin_general_desc'.tr()},
    {'label': 'wg_bin_hazard'.tr(), 'color': const Color(0xFFB71C1C), 'icon': Icons.warning_amber_rounded, 'desc': 'wg_bin_hazard_desc'.tr()},
  ];

  // ✅ ใช้ key แทน hardcode - .tr() ตอน build
  final List<Map<String, dynamic>> _wasteItems = [
    {
      'bin': 1, 'nameKey': 'wg_plastic', 'subKey': 'wg_plastic_sub',
      'icon': Icons.local_drink_outlined, 'bgColor': const Color(0xFFFFFDE7),
      'examples': ['wg_plastic_ex1', 'wg_plastic_ex2', 'wg_plastic_ex3', 'wg_plastic_ex4'],
      'doList': ['wg_plastic_do1', 'wg_plastic_do2', 'wg_plastic_do3', 'wg_plastic_do4'],
      'dontList': ['wg_plastic_dont1', 'wg_plastic_dont2', 'wg_plastic_dont3'],
      'note': 'wg_plastic_note',
    },
    {
      'bin': 1, 'nameKey': 'wg_paper', 'subKey': 'wg_paper_sub',
      'icon': Icons.auto_stories_outlined, 'bgColor': const Color(0xFFFFFDE7),
      'examples': ['wg_paper_ex1', 'wg_paper_ex2', 'wg_paper_ex3', 'wg_paper_ex4'],
      'doList': ['wg_paper_do1', 'wg_paper_do2', 'wg_paper_do3'],
      'dontList': ['wg_paper_dont1', 'wg_paper_dont2', 'wg_paper_dont3'],
      'note': 'wg_paper_note',
    },
    {
      'bin': 1, 'nameKey': 'wg_metal', 'subKey': 'wg_metal_sub',
      'icon': Icons.inventory_2_outlined, 'bgColor': const Color(0xFFFFFDE7),
      'examples': ['wg_metal_ex1', 'wg_metal_ex2', 'wg_metal_ex3', 'wg_metal_ex4'],
      'doList': ['wg_metal_do1', 'wg_metal_do2', 'wg_metal_do3'],
      'dontList': ['wg_metal_dont1', 'wg_metal_dont2'],
      'note': 'wg_metal_note',
    },
    {
      'bin': 1, 'nameKey': 'wg_glass', 'subKey': 'wg_glass_sub',
      'icon': Icons.wine_bar_outlined, 'bgColor': const Color(0xFFFFFDE7),
      'examples': ['wg_glass_ex1', 'wg_glass_ex2', 'wg_glass_ex3', 'wg_glass_ex4'],
      'doList': ['wg_glass_do1', 'wg_glass_do2', 'wg_glass_do3'],
      'dontList': ['wg_glass_dont1', 'wg_glass_dont2'],
      'note': 'wg_glass_note',
    },
    {
      'bin': 2, 'nameKey': 'wg_food', 'subKey': 'wg_food_sub',
      'icon': Icons.restaurant_outlined, 'bgColor': const Color(0xFFE8F5E9),
      'examples': ['wg_food_ex1', 'wg_food_ex2', 'wg_food_ex3', 'wg_food_ex4'],
      'doList': ['wg_food_do1', 'wg_food_do2', 'wg_food_do3'],
      'dontList': ['wg_food_dont1', 'wg_food_dont2'],
      'note': 'wg_food_note',
    },
    {
      'bin': 2, 'nameKey': 'wg_plant', 'subKey': 'wg_plant_sub',
      'icon': Icons.eco_outlined, 'bgColor': const Color(0xFFE8F5E9),
      'examples': ['wg_plant_ex1', 'wg_plant_ex2', 'wg_plant_ex3', 'wg_plant_ex4'],
      'doList': ['wg_plant_do1', 'wg_plant_do2'],
      'dontList': ['wg_plant_dont1', 'wg_plant_dont2'],
      'note': 'wg_plant_note',
    },
    {
      'bin': 3, 'nameKey': 'wg_general', 'subKey': 'wg_general_sub',
      'icon': Icons.delete_outline, 'bgColor': const Color(0xFFE3F2FD),
      'examples': ['wg_general_ex1', 'wg_general_ex2', 'wg_general_ex3', 'wg_general_ex4'],
      'doList': ['wg_general_do1', 'wg_general_do2'],
      'dontList': ['wg_general_dont1', 'wg_general_dont2'],
      'note': 'wg_general_note',
    },
    {
      'bin': 4, 'nameKey': 'wg_battery', 'subKey': 'wg_battery_sub',
      'icon': Icons.battery_alert_outlined, 'bgColor': const Color(0xFFFFEBEE),
      'examples': ['wg_battery_ex1', 'wg_battery_ex2', 'wg_battery_ex3', 'wg_battery_ex4'],
      'doList': ['wg_battery_do1', 'wg_battery_do2', 'wg_battery_do3'],
      'dontList': ['wg_battery_dont1', 'wg_battery_dont2', 'wg_battery_dont3'],
      'note': 'wg_battery_note',
    },
    {
      'bin': 4, 'nameKey': 'wg_bulb', 'subKey': 'wg_bulb_sub',
      'icon': Icons.lightbulb_outline, 'bgColor': const Color(0xFFFFEBEE),
      'examples': ['wg_bulb_ex1', 'wg_bulb_ex2', 'wg_bulb_ex3', 'wg_bulb_ex4'],
      'doList': ['wg_bulb_do1', 'wg_bulb_do2'],
      'dontList': ['wg_bulb_dont1', 'wg_bulb_dont2'],
      'note': 'wg_bulb_note',
    },
    {
      'bin': 4, 'nameKey': 'wg_chemical', 'subKey': 'wg_chemical_sub',
      'icon': Icons.warning_amber_outlined, 'bgColor': const Color(0xFFFFEBEE),
      'examples': ['wg_chemical_ex1', 'wg_chemical_ex2', 'wg_chemical_ex3', 'wg_chemical_ex4'],
      'doList': ['wg_chemical_do1', 'wg_chemical_do2', 'wg_chemical_do3'],
      'dontList': ['wg_chemical_dont1', 'wg_chemical_dont2', 'wg_chemical_dont3'],
      'note': 'wg_chemical_note',
    },
  ];

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedBin == 0) return _wasteItems;
    return _wasteItems.where((w) => w['bin'] == _selectedBin).toList();
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // ✅ rebuild เมื่อเปลี่ยนภาษา
    return Scaffold(
      backgroundColor: const Color(0xFFE3F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D8E6F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'wg_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFE3F5EC),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('wg_select_bin'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                              Icon(bin['icon'] as IconData,
                                  color: _selectedBin == i + 1 ? Colors.white : bin['color'] as Color,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text(bin['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedBin == i + 1 ? Colors.white : bin['color'] as Color)),
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
                          child: Text(_bins[_selectedBin]['desc'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _bins[_selectedBin]['color'] as Color,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
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
                    color: item['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isExpanded ? binColor.withOpacity(0.3) : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: binColor.withOpacity(0.12), shape: BoxShape.circle),
                          child: Icon(item['icon'] as IconData, color: binColor, size: 24),
                        ),
                        title: Text((item['nameKey'] as String).tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text((item['subKey'] as String).tr(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: binColor),
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
                              _sectionTitle('wg_examples'.tr(), binColor),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6, runSpacing: 4,
                                children: (item['examples'] as List).cast<String>().map((e) =>
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: binColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: binColor.withOpacity(0.3)),
                                    ),
                                    child: Text(e.tr(), style: TextStyle(fontSize: 12, color: binColor)),
                                  ),
                                ).toList(),
                              ),
                              const SizedBox(height: 12),
                              _sectionTitle('wg_do'.tr(), const Color(0xFF2E7D32)),
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
                                      Expanded(child: Text(d.tr(), style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _sectionTitle('wg_dont'.tr(), const Color(0xFFB71C1C)),
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
                                      Expanded(child: Text(d.tr(), style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: binColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline, color: binColor, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text((item['note'] as String).tr(),
                                          style: TextStyle(
                                              fontSize: 12, color: binColor,
                                              fontStyle: FontStyle.italic)),
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
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color));
  }
}