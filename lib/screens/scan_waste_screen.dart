import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'activity_screen.dart';

// ==============================
// MODEL
// ==============================
class WasteCategory {
  final String id;
  final String label;
  final Color color;
  final Color lightColor;
  final IconData icon;
  final String binColor;
  final List<String> examples;
  final List<String> disposal;
  final List<String> notes;
  final String disposalNote;
  final List<String> prices;

  const WasteCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.binColor,
    required this.examples,
    required this.disposal,
    required this.notes,
    required this.disposalNote,
    this.prices = const [],
  });
}

const Map<String, WasteCategory> wasteCategories = {
  'recyclable': WasteCategory(
    id: 'recyclable',
    label: 'รีไซเคิล',
    color: Color(0xFFF9A825),      // 🟡 เหลือง
    lightColor: Color(0xFFFFFDE7),
    icon: Icons.recycling,
    binColor: 'เหลือง',
    examples: ['ขวดพลาสติก', 'กล่องกระดาษ', 'กระป๋องโลหะ', 'แก้ว'],
    disposal: [
      'ล้างทำความสะอาดก่อนทิ้ง',
      'ไม่ต้องแกะฝา',
      'แยกประเภทวัสดุ',
    ],
    notes: [],
    disposalNote: 'ไม่รับขยะที่มีสิ่งปนเปื้อน',
    prices: [
      'พลาสติก PET (ขวดน้ำ) : 5–8 บาท/กก.',
      'พลาสติก HDPE (ขวดแชมพู) : 3–5 บาท/กก.',
      'กระดาษ/กล่อง : 1–3 บาท/กก.',
      'อะลูมิเนียม (กระป๋อง) : 25–35 บาท/กก.',
      'เหล็ก/โลหะ : 4–8 บาท/กก.',
      'แก้ว : 0.5–1 บาท/กก.',
    ],
  ),
  'general': WasteCategory(
    id: 'general',
    label: 'ขยะทั่วไป',
    color: Color(0xFF1565C0),      // 🔵 น้ำเงิน
    lightColor: Color(0xFFE3F2FD),
    icon: Icons.delete_outline,
    binColor: 'น้ำเงิน',
    examples: ['ซองพลาสติก', 'โฟม', 'ผ้าอ้อม', 'ถุงพลาสติก'],
    disposal: [],
    notes: [
      'ไม่รับขยะรีไซเคิล',
      'ไม่รับขยะเปียก/อินทรีย์',
      'ไม่รับขยะอันตราย',
    ],
    disposalNote: 'ทิ้งลงถังขยะทั่วไปได้เลย',
    prices: [],
  ),
  'organic': WasteCategory(
    id: 'organic',
    label: 'เศษอาหาร',
    color: Color(0xFF2E7D32),      // 🟢 เขียวเข้ม
    lightColor: Color(0xFFE8F5E9),
    icon: Icons.eco,
    binColor: 'เขียว (ขยะเปียก)',
    examples: ['เศษอาหาร', 'เปลือกผลไม้', 'กระดูก', 'ใบไม้', 'เศษผัก'],
    disposal: [
      'ใส่ถุงก่อนทิ้ง',
      'แยกออกจากขยะรีไซเคิล',
      'แยกน้ำออกก่อนทิ้ง',
    ],
    notes: [],
    disposalNote: 'นำไปทำปุ๋ยหมักได้ — ลดขยะสู่สิ่งแวดล้อม',
    prices: [
      'เศษอาหาร (ทำปุ๋ย) : 0.5–1 บาท/กก.',
      'น้ำมันพืชใช้แล้ว : 8–12 บาท/ลิตร',
    ],
  ),
  'hazardous': WasteCategory(
    id: 'hazardous',
    label: 'ขยะอันตราย',
    color: Color(0xFFB71C1C),      // 🔴 แดงเข้ม
    lightColor: Color(0xFFFFEBEE),
    icon: Icons.warning_amber_rounded,
    binColor: 'แดง (อันตราย)',
    examples: ['ถ่าน AA, AAA', 'แบตมือถือ', 'หลอดไฟ', 'สารเคมี', 'e-waste'],
    disposal: [],
    notes: [
      'ห้ามทิ้งในถังขยะทั่วไป อาจเกิดอัคคีภัย',
      'ไม่แกะถ่านออก อาจรั่วซึมได้',
      'นำไปส่ง 7-Eleven ทุกสาขา',
      'ทิ้งที่กล่องรับถ่านในห้างสรรพสินค้า',
    ],
    disposalNote: 'ต้องการจัดการพิเศษ — ห้ามทิ้งปนกับขยะทั่วไป',
    prices: [
      'แบตมือถือ : 5–15 บาท/ก้อน',
      'อุปกรณ์อิเล็กทรอนิกส์ : แล้วแต่ชนิด',
      'หลอดไฟ LED : รับฟรีที่จุดทิ้งพิเศษ',
    ],
  ),
};

// ==============================
// ROBOFLOW CONFIG
// ==============================
const String _roboflowApiKey = 'RP09BpIhBkP7D7RQde0r';
const String _roboflowModelId = 'bin_sort';
const String _roboflowVersion = '10';

// ==============================
// CLASS MAP — bin_sort/10
// ==============================
String _mapClassToCategory(String rawClass) {
  final c = rawClass.toLowerCase().trim();
  if (c == 'hazardous waste' || c == 'e-waste' ||
      c.contains('hazardous') || c.contains('e-waste') ||
      c.contains('ewaste') || c.contains('battery') ||
      c.contains('chemical') || c.contains('bulb') ||
      c.contains('lithium') || c.contains('li-ion')) return 'hazardous';

  if (c == 'organic waste' || c.contains('organic') ||
      c.contains('food') || c.contains('banana') ||
      c.contains('vegetable') || c.contains('fruit') ||
      c.contains('meat') || c.contains('bone') ||
      c.contains('leaf')) return 'organic';

  if (c == 'general waste' || c.contains('general')) return 'general';

  if (c == 'glass' || c == 'metal' || c == 'paper' ||
      c == 'plastic' || c == 'recyclable waste' || c == 'bin-sort' ||
      c.contains('glass') || c.contains('metal') || c.contains('paper') ||
      c.contains('plastic') || c.contains('recyclable') ||
      c.contains('cardboard') || c.contains('bottle') ||
      c.contains('can') || c.contains('aluminum') ||
      c.contains('tin')) return 'recyclable';

  return 'general';
}

// ==============================
// HAVERSINE — คำนวณระยะทาง (เมตร)
// ==============================
double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

// ==============================
// SCREEN
// ==============================
class ScanWasteScreen extends StatefulWidget {
  const ScanWasteScreen({Key? key}) : super(key: key);

  @override
  State<ScanWasteScreen> createState() => _ScanWasteScreenState();
}

class _ScanWasteScreenState extends State<ScanWasteScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  WasteCategory? _detectedCategory;
  double _confidence = 0.0;

  // ระยะห่างถังใกล้สุด (เมตร) — -1 = ยังไม่รู้
  double _distanceMeters = -1;
  bool _withinRadius = false; // อยู่ในรัศมี 1 เมตรไหม
  int _pointsEarned = 0;      // แต้มที่ได้จริง

  Uint8List? _imageBytes;
  bool _showResultSheet = false;
  int _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _userPoints = (doc.data()?['points'] ?? 0) as int);
      }
    } catch (_) {}
  }

  // ==============================
  // GPS — รองรับทั้ง Web และ Mobile
  // ==============================
  Future<Map<String, double>?> _getCurrentPosition() async {
    try {
      if (kIsWeb) {
        // Web: ใช้ geolocator ซึ่งรองรับ Web ผ่าน browser Geolocation API
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied ||
              req == LocationPermission.deniedForever) return null;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return {'lat': pos.latitude, 'lng': pos.longitude};
      } else {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition();
        return {'lat': pos.latitude, 'lng': pos.longitude};
      }
    } catch (e) {
      debugPrint('GPS error: $e');
      return null;
    }
  }

  // ==============================
  // หาถังขยะใกล้สุดจาก Firestore bins
  // ==============================
  Future<_BinResult> _getNearestBinDistance() async {
    final myPos = await _getCurrentPosition();
    if (myPos == null) {
      return _BinResult(distanceMeters: -1, withinRadius: false);
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bins')
          .get();

      double minDist = double.infinity;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // รองรับหลาย field name
        double? lat = (data['lat'] ?? data['latitude'])?.toDouble();
        double? lng = (data['lng'] ?? data['longitude'] ?? data['long'])?.toDouble();

        // รองรับ GeoPoint
        if (lat == null && data['location'] is GeoPoint) {
          final gp = data['location'] as GeoPoint;
          lat = gp.latitude;
          lng = gp.longitude;
        }

        if (lat == null || lng == null) continue;

        final dist = _haversineDistance(
            myPos['lat']!, myPos['lng']!, lat, lng);
        if (dist < minDist) minDist = dist;
      }

      if (minDist == double.infinity) {
        return _BinResult(distanceMeters: -1, withinRadius: false);
      }

      return _BinResult(
        distanceMeters: minDist,
        withinRadius: minDist <= 1.0,
      );
    } catch (e) {
      debugPrint('Firestore bins error: $e');
      return _BinResult(distanceMeters: -1, withinRadius: false);
    }
  }

  // ==============================
  // PICK IMAGE & SCAN
  // ==============================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file == null) return;

      setState(() {
        _isProcessing = true;
        _showResultSheet = false;
        _detectedCategory = null;
        _imageBytes = null;
        _distanceMeters = -1;
        _withinRadius = false;
        _pointsEarned = 0;
      });

      final bytes = await file.readAsBytes();
      setState(() => _imageBytes = bytes);

      // ดึง GPS + ถัง พร้อมกัน
      final binResult = await _getNearestBinDistance();
      final result = await _callRoboflowAPI(bytes);

      if (result != null) {
        final category =
            wasteCategories[result['categoryId']] ?? wasteCategories['general']!;

        // คำนวณแต้ม: อยู่ในรัศมี 1 เมตร = +1 แต้ม, ไม่อยู่ = 0
        final pts = binResult.withinRadius ? 1 : 0;

        setState(() {
          _detectedCategory = category;
          _confidence = result['confidence'];
          _distanceMeters = binResult.distanceMeters;
          _withinRadius = binResult.withinRadius;
          _pointsEarned = pts;
          _showResultSheet = true;
          _isProcessing = false;
        });

        await _saveToHistory(bytes, result, binResult.distanceMeters, pts);
      } else {
        setState(() {
          _detectedCategory = null;
          _distanceMeters = binResult.distanceMeters;
          _withinRadius = binResult.withinRadius;
          _showResultSheet = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Pick image error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==============================
  // ROBOFLOW API
  // ==============================
  Future<Map<String, dynamic>?> _callRoboflowAPI(Uint8List bytes) async {
    if (_roboflowApiKey == 'YOUR_ROBOFLOW_API_KEY') {
      return _demoDetect(bytes);
    }
    try {
      final base64Image = base64Encode(bytes);
      final uri = Uri.parse(
        'https://detect.roboflow.com/$_roboflowModelId/$_roboflowVersion'
        '?api_key=$_roboflowApiKey',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: base64Image,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List?;
        if (predictions == null || predictions.isEmpty) return null;
        final best = predictions.reduce((a, b) =>
            (a['confidence'] as double) > (b['confidence'] as double) ? a : b);
        return {
          'categoryId': _mapClassToCategory(best['class'] as String),
          'label': best['class'],
          'confidence': (best['confidence'] as double) * 100,
        };
      }
    } catch (e) {
      debugPrint('Roboflow error: $e');
    }
    return null;
  }

  Map<String, dynamic> _demoDetect(Uint8List bytes) {
    final cats = ['recyclable', 'general', 'organic', 'hazardous'];
    final labels = ['plastic', 'general waste', 'organic waste', 'hazardous waste'];
    final idx = DateTime.now().millisecond % 4;
    return {
      'categoryId': cats[idx],
      'label': labels[idx],
      'confidence': 75.0 + (DateTime.now().second % 20).toDouble(),
    };
  }

  // ==============================
  // SAVE HISTORY
  // ==============================
  Future<void> _saveToHistory(
    Uint8List bytes,
    Map<String, dynamic> result,
    double distance,
    int pointsEarned,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseStorage.instance.ref(
          'scan_history/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('scan_history')
          .add({
        'categoryId': result['categoryId'],
        'label': result['label'],
        'confidence': result['confidence'],
        'imageUrl': imageUrl,
        'distanceMeters': distance,
        'pointsEarned': pointsEarned,
        'withinRadius': pointsEarned > 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // อัปเดตแต้มเฉพาะเมื่ออยู่ในรัศมี
      if (pointsEarned > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'points': FieldValue.increment(pointsEarned)});
        if (mounted) setState(() => _userPoints += pointsEarned);
      }
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  void _resetScan() {
    setState(() {
      _showResultSheet = false;
      _detectedCategory = null;
      _imageBytes = null;
      _confidence = 0;
      _distanceMeters = -1;
      _withinRadius = false;
      _pointsEarned = 0;
    });
  }

  // ==============================
  // BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _imageBytes != null && !_showResultSheet
                      ? _buildImagePreview()
                      : _showResultSheet
                          ? const SizedBox.shrink()
                          : _buildScanArea(),
                ),
                if (!_showResultSheet) _buildBottomButtons(),
              ],
            ),
          ),
          if (_isProcessing) _buildProcessingOverlay(),
          if (_showResultSheet && _detectedCategory != null) _buildResultSheet(),
          if (_showResultSheet && _detectedCategory == null) _buildNoDetectionSheet(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('สแกนขยะ',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 4),
                Text('$_userPoints แต้ม',
                    style: const TextStyle(color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanArea() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CustomPaint(
              painter: _ScanFramePainter(),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.document_scanner_outlined,
                        color: Colors.white.withOpacity(0.35), size: 52),
                    const SizedBox(height: 12),
                    Text('กดปุ่มด้านล่างเพื่อเลือกภาพ',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ถ่ายภาพหรือเลือกจากอัลบั้ม\nระบบจะวิเคราะห์ประเภทขยะให้อัตโนมัติ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4),
                fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 16),
          // แสดงเงื่อนไขแต้ม
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 16),
                SizedBox(width: 6),
                Text(
                  'ต้องอยู่ในรัศมี 1 เมตรจากถังขยะ\nเพื่อรับ +1 แต้ม',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(_imageBytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(children: [
                  Icon(Icons.photo_library_outlined, color: Colors.white, size: 26),
                  SizedBox(height: 4),
                  Text('อัลบั้ม', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 4),
                )],
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ActivityScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(children: [
                  Icon(Icons.history, color: Colors.white, size: 26),
                  SizedBox(height: 4),
                  Text('ประวัติ', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 3),
              SizedBox(height: 16),
              Text('กำลังวิเคราะห์...',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w500)),
              SizedBox(height: 6),
              Text('กำลังตรวจสอบระยะห่างถังขยะ...',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSheet() {
    final cat = _detectedCategory!;

    // สร้างข้อความระยะห่าง
    String distText;
    Color distBg;
    Color distBorder;
    Color distTextColor;
    Color distIconColor;

    if (_distanceMeters < 0) {
      distText = 'ไม่สามารถระบุตำแหน่งได้';
      distBg = Colors.grey.shade100;
      distBorder = Colors.grey;
      distTextColor = Colors.grey;
      distIconColor = Colors.grey;
    } else if (_withinRadius) {
      distText = 'อยู่ในรัศมี ${_distanceMeters.toStringAsFixed(1)} ม. ✓';
      distBg = const Color(0xFFE8F5E9);
      distBorder = const Color(0xFF2E7D32);
      distTextColor = const Color(0xFF388E3C);
      distIconColor = const Color(0xFF2E7D32);
    } else {
      distText = 'ห่างถัง ${_distanceMeters.toStringAsFixed(1)} ม. (เกิน 1 ม.)';
      distBg = const Color(0xFFFFEBEE);
      distBorder = const Color(0xFFF44336);
      distTextColor = const Color(0xFFB71C1C);
      distIconColor = const Color(0xFFF44336);
    }

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),

              // ระยะห่าง + แต้ม
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    // ระยะห่าง badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: distBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: distBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                color: distIconColor, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(distText,
                                  style: TextStyle(fontSize: 11,
                                      color: distTextColor,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // แต้ม badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _pointsEarned > 0
                            ? const Color(0xFFFFF9C4)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded,
                              color: _pointsEarned > 0
                                  ? const Color(0xFFF57F17)
                                  : Colors.grey,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _pointsEarned > 0
                                ? '+$_pointsEarned แต้ม'
                                : 'ไม่ได้แต้ม',
                            style: TextStyle(
                              fontSize: 12,
                              color: _pointsEarned > 0
                                  ? const Color(0xFFF57F17)
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // แจ้งเตือนถ้าไม่อยู่ในรัศมี
              if (!_withinRadius && _distanceMeters >= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'เดินไปใกล้ถังขยะให้อยู่ในรัศมี 1 เมตร\nแล้วสแกนใหม่เพื่อรับ +1 แต้ม',
                            style: TextStyle(fontSize: 12,
                                color: Colors.orange.shade800, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Image
              if (_imageBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(_imageBytes!,
                            height: 180, width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cat.color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(cat.icon, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(cat.label,
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              if (_confidence > 0) ...[
                                const SizedBox(width: 6),
                                Text('${_confidence.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildInfoCard(cat),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resetScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cat.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('สแกนชิ้นต่อไป →',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(WasteCategory cat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cat.lightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.delete_outline, color: cat.color, size: 18),
            const SizedBox(width: 6),
            Text('ถังสี${cat.binColor}',
                style: TextStyle(color: cat.color,
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          if (cat.examples.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('ตัวอย่าง',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4,
                children: cat.examples
                    .map((e) => _buildTag(e, cat.color)).toList()),
          ],
          if (cat.disposal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('วิธีทิ้ง',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ...cat.disposal.map((d) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: cat.color, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(d,
                        style: const TextStyle(fontSize: 12))),
                  ]),
            )),
          ],
          if (cat.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('หมายเหตุ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ...cat.notes.map((n) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      n.contains('ห้าม') || n.contains('ไม่')
                          ? Icons.cancel : Icons.info_outline,
                      color: n.contains('ห้าม') || n.contains('ไม่')
                          ? Colors.red : Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(n,
                        style: const TextStyle(fontSize: 12))),
                  ]),
            )),
          ],
          if (cat.prices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.storefront_outlined,
                        color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text('ราคารับซื้อร้านของเก่า',
                        style: TextStyle(color: Colors.amber,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  ...cat.prices.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(color: Colors.amber, fontSize: 12)),
                        Expanded(child: Text(p,
                            style: TextStyle(fontSize: 12,
                                color: Colors.grey[700]))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          if (cat.disposalNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: cat.color, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(cat.disposalNote,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildNoDetectionSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, color: Colors.orange, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('ไม่พบขยะในภาพ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('ลองเลือกภาพที่ชัดขึ้น หรือถ่ายภาพใกล้ๆ',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('เลือกจากอัลบั้ม'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('สแกนใหม่'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ==============================
// BIN RESULT MODEL
// ==============================
class _BinResult {
  final double distanceMeters;
  final bool withinRadius;
  const _BinResult({required this.distanceMeters, required this.withinRadius});
}

// ==============================
// SCAN FRAME PAINTER
// ==============================
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    const r = 10.0;
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + len), paint);
    canvas.drawLine(Offset(size.width - r - len, 0),
        Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r),
        Offset(size.width, r + len), paint);
    canvas.drawLine(Offset(0, size.height - r - len),
        Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height),
        Offset(r + len, size.height), paint);
    canvas.drawLine(Offset(size.width - r - len, size.height),
        Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r - len),
        Offset(size.width, size.height - r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
