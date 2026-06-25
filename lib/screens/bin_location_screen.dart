import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ── ประเภทถัง ─────────────────────────────────────────────────────────────────
enum BinType { all, general, recycle, organic, hazardous }

extension BinTypeExt on BinType {
  String get label {
    switch (this) {
      case BinType.all:
        return 'ทั้งหมด';
      case BinType.general:
        return 'ทั่วไป';
      case BinType.recycle:
        return 'รีไซเคิล';
      case BinType.organic:
        return 'อินทรีย์';
      case BinType.hazardous:
        return 'อันตราย';
    }
  }

  Color get color {
    switch (this) {
      case BinType.all:
        return Colors.grey;
      case BinType.general:
        return const Color(0xFF2196F3);
      case BinType.recycle:
        return const Color(0xFF4CAF50);
      case BinType.organic:
        return const Color(0xFF8BC34A);
      case BinType.hazardous:
        return const Color(0xFFFF9800);
    }
  }

  IconData get icon {
    switch (this) {
      case BinType.all:
        return Icons.delete_outline;
      case BinType.general:
        return Icons.delete_outline;
      case BinType.recycle:
        return Icons.recycling;
      case BinType.organic:
        return Icons.eco_outlined;
      case BinType.hazardous:
        return Icons.warning_amber_outlined;
    }
  }
}

BinType binTypeFromString(String? s) {
  switch (s) {
    case 'รีไซเคิล':
      return BinType.recycle;
    case 'อินทรีย์':
      return BinType.organic;
    case 'อันตราย':
      return BinType.hazardous;
    default:
      return BinType.general;
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class BinData {
  final String id;
  final String name;
  final BinType type;
  final List<BinType> types; // หลายประเภท
  final LatLng position;
  final String addedBy;
  final DateTime? lastUpdate;
  final String? imageUrl;

  BinData({
    required this.id,
    required this.name,
    required this.type,
    required this.types,
    required this.position,
    required this.addedBy,
    this.lastUpdate,
    this.imageUrl,
  });

  factory BinData.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // รองรับทั้ง array 'types' และ string 'type'
    List<BinType> typeList = [];
    if (d['types'] != null && d['types'] is List) {
      typeList = (d['types'] as List)
          .map((t) => binTypeFromString(t as String?))
          .toList();
    } else if (d['type'] != null) {
      final typeStr = d['type'] as String;
      // กรณีเก็บแบบ "ทั่วไป, รีไซเคิล"
      typeList = typeStr.split(',')
          .map((t) => binTypeFromString(t.trim()))
          .toList();
    }
    if (typeList.isEmpty) typeList = [BinType.general];

    return BinData(
      id: doc.id,
      name: d['name'] ?? 'ถังขยะ',
      type: typeList.first,
      types: typeList,
      position: LatLng(
        (d['lat'] as num?)?.toDouble() ?? 0.0,
        (d['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      addedBy: d['addedBy'] ?? 'ไม่ระบุ',
      lastUpdate: (d['lastUpdate'] as Timestamp?)?.toDate(),
      imageUrl: d['imageUrl'],
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class BinLocationScreen extends StatefulWidget {
  const BinLocationScreen({super.key});

  @override
  State<BinLocationScreen> createState() => _BinLocationScreenState();
}

class _BinLocationScreenState extends State<BinLocationScreen> {
  LatLng? _userLocation;
  LatLng? _pendingLocation;
  BinType _selectedFilter = BinType.all;
  List<BinData> _bins = [];
  bool _loadingBins = true;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _listenBins(); // เปลี่ยนเป็น real-time stream
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  void _listenBins() {
    FirebaseFirestore.instance.collection('bins').snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _bins = snap.docs.map((d) => BinData.fromFirestore(d)).toList();
          _loadingBins = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loadingBins = false);
    });
  }

  // ยังคงไว้สำหรับ onAdded callback
  Future<void> _loadBins() async {}

  List<BinData> get _filteredBins {
    if (_selectedFilter == BinType.all) return _bins;
    return _bins.where((b) => b.type == _selectedFilter).toList();
  }

  String _formatDistance(BinData bin) {
    if (_userLocation == null) return '';
    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      bin.position.latitude,
      bin.position.longitude,
    );
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km.';
    }
    return '${meters.toInt()} ม.';
  }

  void _showBinDetail(BinData bin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BinDetailSheet(bin: bin, distance: _formatDistance(bin)),
    );
  }

  void _showAddBin() {
    final targetLocation = _pendingLocation ?? _userLocation;
    if (targetLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังหาตำแหน่งของคุณ...')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBinSheet(userLocation: targetLocation, onAdded: _loadBins),
    ).then((_) {
      if (mounted) setState(() => _pendingLocation = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultCenter = _userLocation ?? const LatLng(18.7883, 98.9853);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        title: const Text(
          'ตำแหน่งถังขยะ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() => _pendingLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.binsort_new',
              ),
              MarkerLayer(
                markers: [
                    if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 64,
                      height: 64,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: Icon(Icons.my_location, color: Colors.blue, size: 36),
                        ),
                      ),
                    ),
                  if (_pendingLocation != null)
                    Marker(
                      point: _pendingLocation!,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 42),
                    ),
                  ..._filteredBins.map((bin) => Marker(
                        point: bin.position,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showBinDetail(bin),
                          child: _BinMarker(type: bin.type),
                        ),
                      )),
                ],
              ),
            ],
          ),
          // ── Filter Chips ──────────────────────────────────────────────────
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  BinType.all,
                  BinType.general,
                  BinType.recycle,
                  BinType.organic,
                  BinType.hazardous,
                ].map((t) {
                  final selected = _selectedFilter == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? t.color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.color, width: 1.5),
                          boxShadow: selected
                              ? [BoxShadow(color: t.color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon, size: 14, color: selected ? Colors.white : t.color),
                            const SizedBox(width: 4),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : t.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── FAB ───────────────────────────────────────────────────────────
          Positioned(
            bottom: 60,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: _pendingLocation != null ? Colors.red : const Color(0xFF4CAF50),
              onPressed: _showAddBin,
              child: Icon(
                _pendingLocation != null ? Icons.add_location : Icons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),

          // ── Banner pending ────────────────────────────────────────────────
          if (_pendingLocation != null)
            Positioned(
              bottom: 125,
              left: 16,
              right: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'เลือกตำแหน่งแล้ว — กด + เพื่อเพิ่มถัง',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _pendingLocation = null),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),

          if (_loadingBins) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// ── Bin Marker ────────────────────────────────────────────────────────────────
class _BinMarker extends StatelessWidget {
  final BinType type;
  const _BinMarker({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: type.color, width: 2.5),
        boxShadow: [BoxShadow(color: type.color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Center(child: Icon(type.icon, color: type.color, size: 22)),
    );
  }
}

// ── Bin Detail Sheet ──────────────────────────────────────────────────────────
class _BinDetailSheet extends StatelessWidget {
  final BinData bin;
  final String distance;
  const _BinDetailSheet({required this.bin, required this.distance});

  @override
  Widget build(BuildContext context) {
    final lastUpdateStr = bin.lastUpdate != null
        ? DateFormat('dd MMM yyyy').format(bin.lastUpdate!)
        : 'วันนี้';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // รูปภาพ — รองรับทั้ง URL และ base64
          if (bin.imageUrl != null && bin.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bin.imageUrl!.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(bin.imageUrl!.split(',').last),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : Image.network(
                      bin.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bin.type.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(bin.type.icon, color: bin.type.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bin.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    // แสดงทุกประเภทเป็น chip
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: bin.types.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(fontSize: 12, color: t.color, fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              if (distance.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 2),
                    Text(distance, style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          _InfoRow(icon: Icons.person_outline, label: 'เพิ่มโดย', value: bin.addedBy),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.update, label: 'อัปเดตล่าสุด', value: lastUpdateStr),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${bin.position.latitude},${bin.position.longitude}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.navigation_outlined, color: Colors.white, size: 18),
                  label: const Text('นำทางไปถัง', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Add Bin Sheet ─────────────────────────────────────────────────────────────
class _AddBinSheet extends StatefulWidget {
  final LatLng userLocation;
  final VoidCallback onAdded;
  const _AddBinSheet({required this.userLocation, required this.onAdded});

  @override
  State<_AddBinSheet> createState() => _AddBinSheetState();
}

class _AddBinSheetState extends State<_AddBinSheet> {
  final _nameController = TextEditingController();
  final Set<BinType> _selectedTypes = {BinType.general};
  XFile? _pickedXFile;
  Uint8List? _pickedBytes;
  String? _base64Image; // เก็บ base64 แทน Storage
  bool _uploading = false;
  String _uploadStatus = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 20,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      if (bytes.lengthInBytes > 60 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('รูปใหญ่เกินไป กรุณาเลือกรูปที่เล็กกว่า')),
          );
        }
        return;
      }
      final b64 = base64Encode(bytes);
      setState(() {
        _pickedXFile = xfile;
        _pickedBytes = bytes;
        _base64Image = 'data:image/jpeg;base64,$b64';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อสถานที่')),
      );
      return;
    }
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกประเภทถังอย่างน้อย 1 ประเภท')),
      );
      return;
    }

    setState(() { _uploading = true; _uploadStatus = 'กำลังบันทึกข้อมูล...'; });

    try {
      // ใช้ base64 แทน Storage — ไม่ต้อง upload ไปไหน
      final imageData = _base64Image ?? '';

      // ดึงชื่อผู้ใช้
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = user != null
          ? await FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          : null;
      final displayName = userDoc?.data()?['name'] ?? user?.displayName ?? 'ไม่ระบุ';

      // บันทึก Firestore
      final typeList = _selectedTypes.map((t) => t.label).toList();
      await FirebaseFirestore.instance.collection('bins').add({
        'name': name,
        'type': typeList.length == 1 ? typeList.first : typeList.join(', '),
        'types': typeList,
        'lat': widget.userLocation.latitude,
        'lng': widget.userLocation.longitude,
        'addedBy': displayName,
        'lastUpdate': Timestamp.now(),
        'imageUrl': imageData,
      });

      // บันทึกประวัติกิจกรรม
      if (user != null) {
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': user.uid,
          'type': 'add_bin',
          'title': 'เพิ่มจุดถังขยะ',
          'detail': name,
          'binTypes': _selectedTypes.map((t) => t.label).toList(),
          'points': 1,
          'timestamp': Timestamp.now(),
        });
      }

      // เพิ่มแต้ม +2
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'points': FieldValue.increment(1)});
      }

      if (mounted) {
        widget.onAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ เพิ่มถังขยะสำเร็จ! (+1 แต้ม)'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const Icon(Icons.add_location_alt_outlined, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                const Text('เพิ่มจุดถังขยะใหม่',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF4CAF50), size: 14),
                      SizedBox(width: 4),
                      Text('รับ +1 แต้ม',
                          style: TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('เมื่อเพิ่มสำเร็จ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 16),

            // ชื่อสถานที่
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'ชื่อจุด / สถานที่',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // ประเภทถัง (multi-select)
            Row(
              children: [BinType.general, BinType.recycle, BinType.organic, BinType.hazardous].map((t) {
                final sel = _selectedTypes.contains(t);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (sel) {
                          _selectedTypes.remove(t);
                        } else {
                          _selectedTypes.add(t);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.color : t.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.color, width: sel ? 0 : 1),
                        ),
                        child: Column(
                          children: [
                            if (sel)
                              const Icon(Icons.check_circle, color: Colors.white, size: 18)
                            else
                              Icon(t.icon, color: t.color, size: 18),
                            const SizedBox(height: 2),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: sel ? Colors.white : t.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // ถ่ายรูป
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: _pickedBytes != null ? 120 : 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: _pickedBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _pickedBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 120,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 18),
                          SizedBox(width: 8),
                          Text('ถ่ายภาพประกอบ (ไม่บังคับ)',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ปุ่มยืนยัน
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _uploading ? Colors.grey[300] : const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  _uploading
                      ? (_uploadStatus.isNotEmpty ? _uploadStatus : 'กำลังบันทึก...')
                      : '✅ เพิ่มจุดถังขยะ (+1 แต้ม)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
