import 'dart:async';
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
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import 'activity_screen.dart';

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
  final bool notesAreWarnings;

  const WasteCategory({
    required this.id, required this.label, required this.color,
    required this.lightColor, required this.icon, required this.binColor,
    required this.examples, required this.disposal, required this.notes,
    required this.disposalNote, this.prices = const [], this.notesAreWarnings = false,
  });
}

Map<String, WasteCategory> get wasteCategories => {
  'recyclable': WasteCategory(
    id: 'recyclable',
    label: 'cat_recyclable'.tr(),
    color: const Color(0xFFF9A825),
    lightColor: const Color(0xFFFFFDE7),
    icon: Icons.recycling,
    binColor: 'bin_yellow'.tr(),
    examples: [
      'sw_recyclable_ex1'.tr(), 'sw_recyclable_ex2'.tr(),
      'sw_recyclable_ex3'.tr(), 'sw_recyclable_ex4'.tr(),
    ],
    disposal: [
      'sw_recyclable_do1'.tr(), 'sw_recyclable_do2'.tr(), 'sw_recyclable_do3'.tr(),
    ],
    notes: [],
    disposalNote: 'sw_recyclable_note'.tr(),
    prices: [
      'sw_recyclable_price1'.tr(), 'sw_recyclable_price2'.tr(), 'sw_recyclable_price3'.tr(),
      'sw_recyclable_price4'.tr(), 'sw_recyclable_price5'.tr(), 'sw_recyclable_price6'.tr(),
    ],
  ),
  'general': WasteCategory(
    id: 'general',
    label: 'cat_general'.tr(),
    color: const Color(0xFF1565C0),
    lightColor: const Color(0xFFE3F2FD),
    icon: Icons.delete_outline,
    binColor: 'bin_blue'.tr(),
    examples: [
      'sw_general_ex1'.tr(), 'sw_general_ex2'.tr(),
      'sw_general_ex3'.tr(), 'sw_general_ex4'.tr(),
    ],
    disposal: [],
    notes: [
      'sw_general_note1'.tr(), 'sw_general_note2'.tr(), 'sw_general_note3'.tr(),
    ],
    notesAreWarnings: true,
    disposalNote: 'sw_general_disposal_note'.tr(),
    prices: [],
  ),
  'organic': WasteCategory(
    id: 'organic',
    label: 'cat_organic'.tr(),
    color: const Color(0xFF2E7D32),
    lightColor: const Color(0xFFE8F5E9),
    icon: Icons.eco,
    binColor: 'bin_green'.tr(),
    examples: [
      'sw_organic_ex1'.tr(), 'sw_organic_ex2'.tr(), 'sw_organic_ex3'.tr(),
      'sw_organic_ex4'.tr(), 'sw_organic_ex5'.tr(),
    ],
    disposal: [
      'sw_organic_do1'.tr(), 'sw_organic_do2'.tr(), 'sw_organic_do3'.tr(),
    ],
    notes: [],
    disposalNote: 'sw_organic_disposal_note'.tr(),
    prices: [
      'sw_organic_price1'.tr(), 'sw_organic_price2'.tr(),
    ],
  ),
  'hazardous': WasteCategory(
    id: 'hazardous',
    label: 'cat_hazardous'.tr(),
    color: const Color(0xFFB71C1C),
    lightColor: const Color(0xFFFFEBEE),
    icon: Icons.warning_amber_rounded,
    binColor: 'bin_red'.tr(),
    examples: [
      'sw_hazardous_ex1'.tr(), 'sw_hazardous_ex2'.tr(), 'sw_hazardous_ex3'.tr(),
      'sw_hazardous_ex4'.tr(), 'sw_hazardous_ex5'.tr(),
    ],
    disposal: [],
    notes: [
      'sw_hazardous_note1'.tr(), 'sw_hazardous_note2'.tr(),
      'sw_hazardous_note3'.tr(), 'sw_hazardous_note4'.tr(),
    ],
    notesAreWarnings: true,
    disposalNote: 'sw_hazardous_disposal_note'.tr(),
    prices: [
      'sw_hazardous_price1'.tr(), 'sw_hazardous_price2'.tr(), 'sw_hazardous_price3'.tr(),
    ],
  ),
};

const String _roboflowApiKey = 'v60xeMgk6Gj4T0NXgAeW';
const String _roboflowModelId = 'bin_sort-jqebj';
const String _roboflowVersion = '3';

String _mapClassToCategory(String rawClass) {
  final c = rawClass.toLowerCase().trim();
  if (c == 'hazardous waste' || c == 'e-waste' || c.contains('hazardous') ||
      c.contains('e-waste') || c.contains('ewaste') || c.contains('battery') ||
      c.contains('chemical') || c.contains('bulb') || c.contains('lithium') ||
      c.contains('li-ion')) return 'hazardous';
  if (c == 'organic waste' || c.contains('organic') || c.contains('food') ||
      c.contains('banana') || c.contains('vegetable') || c.contains('fruit') ||
      c.contains('meat') || c.contains('bone') || c.contains('leaf')) return 'organic';
  if (c == 'general waste' || c.contains('general')) return 'general';
  if (c == 'glass' || c == 'metal' || c == 'paper' || c == 'plastic' ||
      c == 'recyclable waste' || c == 'bin-sort' || c.contains('glass') ||
      c.contains('metal') || c.contains('paper') || c.contains('plastic') ||
      c.contains('recyclable') || c.contains('cardboard') || c.contains('bottle') ||
      c.contains('can') || c.contains('aluminum') || c.contains('tin')) return 'recyclable';
  return 'general';
}

double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class ScanWasteScreen extends StatefulWidget {
  const ScanWasteScreen({Key? key}) : super(key: key);
  @override
  State<ScanWasteScreen> createState() => _ScanWasteScreenState();
}

class _ScanWasteScreenState extends State<ScanWasteScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  WasteCategory? _detectedCategory;
  WasteCategory? _originalCategory;
  double _confidence = 0.0;
  double _distanceMeters = -1;
  bool _withinRadius = false;
  int _pointsEarned = 0;
  Uint8List? _imageBytes;
  bool _showResultSheet = false;
  int _userPoints = 0;
  bool? _hasContamination;
  bool _binsExist = false;

  // ✅ ระยะห่างจากถังขยะแบบ real-time
  List<Map<String, double>> _binPositions = [];
  double? _liveDistanceMeters;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
    _checkBinsExist();
    _loadBinsList();
    _startLiveLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _checkBinsExist() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('bins').limit(1).get();
      if (mounted) setState(() => _binsExist = snap.docs.isNotEmpty);
    } catch (e) {
      debugPrint('Error checking bins: $e');
    }
  }

  // ✅ โหลดตำแหน่งถังขยะทั้งหมดไว้ล่วงหน้า สำหรับคำนวณระยะแบบ real-time
  Future<void> _loadBinsList() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('bins').get();
      final positions = <Map<String, double>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        double? lat = (data['lat'] ?? data['latitude'])?.toDouble();
        double? lng = (data['lng'] ?? data['longitude'] ?? data['long'])?.toDouble();
        if (lat == null && data['location'] is GeoPoint) {
          final gp = data['location'] as GeoPoint;
          lat = gp.latitude; lng = gp.longitude;
        }
        if (lat != null && lng != null) positions.add({'lat': lat, 'lng': lng});
      }
      if (mounted) setState(() => _binPositions = positions);
    } catch (e) {
      debugPrint('Load bins list error: $e');
    }
  }

  // ✅ ฟังตำแหน่งผู้ใช้แบบ stream ต่อเนื่อง อัปเดตระยะห่างทุกครั้งที่ขยับ
  Future<void> _startLiveLocationTracking() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2, // ✅ อัปเดตทุกๆ 2 เมตรที่ขยับ
        ),
      ).listen((position) {
        if (!mounted || _binPositions.isEmpty) return;
        double minDist = double.infinity;
        for (final bin in _binPositions) {
          final dist = _haversineDistance(
              position.latitude, position.longitude, bin['lat']!, bin['lng']!);
          if (dist < minDist) minDist = dist;
        }
        if (minDist != double.infinity && mounted) {
          setState(() => _liveDistanceMeters = minDist);
        }
      }, onError: (e) => debugPrint('Position stream error: $e'));
    } catch (e) {
      debugPrint('Live location error: $e');
    }
  }

  Future<void> _loadUserPoints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _userPoints = (doc.data()?['points'] ?? 0) as int);
      }
    } catch (_) {}
  }

  Future<Map<String, double>?> _getCurrentPosition() async {
    try {
      if (kIsWeb) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final req = await Geolocator.requestPermission();
          if (req == LocationPermission.denied || req == LocationPermission.deniedForever) return null;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
        return {'lat': pos.latitude, 'lng': pos.longitude};
      } else {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) await Geolocator.requestPermission();
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
        return {'lat': pos.latitude, 'lng': pos.longitude};
      }
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  Future<_BinResult> _getNearestBinDistance() async {
    final myPos = await _getCurrentPosition();
    if (myPos == null) {
      return const _BinResult(distanceMeters: -1, withinRadius: false);
    }
    try {
      final snapshot = await FirebaseFirestore.instance.collection('bins').get();
      if (snapshot.docs.isEmpty) {
        return const _BinResult(distanceMeters: -1, withinRadius: false);
      }
      
      double minDist = double.infinity;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        double? lat = (data['lat'] ?? data['latitude'])?.toDouble();
        double? lng = (data['lng'] ?? data['longitude'] ?? data['long'])?.toDouble();
        if (lat == null && data['location'] is GeoPoint) {
          final gp = data['location'] as GeoPoint;
          lat = gp.latitude; lng = gp.longitude;
        }
        if (lat == null || lng == null) continue;
        final dist = _haversineDistance(myPos['lat']!, myPos['lng']!, lat, lng);
        if (dist < minDist) minDist = dist;
      }
      if (minDist == double.infinity) return const _BinResult(distanceMeters: -1, withinRadius: false);
      return _BinResult(distanceMeters: minDist, withinRadius: minDist <= 6.5);
    } catch (e) {
      debugPrint('Bin distance error: $e');
      return const _BinResult(distanceMeters: -1, withinRadius: false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
      if (file == null) return;
      setState(() {
        _isProcessing = true; _showResultSheet = false;
        _detectedCategory = null; _originalCategory = null; _imageBytes = null;
        _distanceMeters = -1; _withinRadius = false; _pointsEarned = 0; _hasContamination = null;
      });
      final bytes = await file.readAsBytes();
      setState(() => _imageBytes = bytes);
      
      final binResult = await _getNearestBinDistance();

      Map<String, dynamic>? result;
      bool connectionFailed = false;
      try {
        result = await _callRoboflowAPI(bytes);
      } on _ApiConnectionException catch (e) {
        debugPrint('API connection error: ${e.message}');
        connectionFailed = true;
      }

      if (connectionFailed) {
        // ✅ เชื่อมต่อ/timeout ไม่สำเร็จ ไม่ใช่ "ไม่เจอขยะ" — แจ้งให้ลองใหม่แทน
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('scan_connection_error'.tr())),
          );
        }
        return;
      }

      if (result != null) {
        final resultData = result; // ✅ ทำให้เป็น final เพื่อให้ type promotion ใช้ได้ข้างใน closure ของ setState
        final category = wasteCategories[resultData['categoryId']] ?? wasteCategories['general']!;
        final pts = binResult.withinRadius ? 1 : 0;
        setState(() {
          _detectedCategory = category; _originalCategory = category;
          _confidence = resultData['confidence']; _distanceMeters = binResult.distanceMeters;
          _withinRadius = binResult.withinRadius; _pointsEarned = pts;
          _showResultSheet = true; _isProcessing = false;
        });
        await _saveToHistory(bytes, resultData, binResult.distanceMeters, pts);
      } else {
        setState(() {
          _detectedCategory = null; _originalCategory = null;
          _distanceMeters = binResult.distanceMeters; _withinRadius = binResult.withinRadius;
          _showResultSheet = true; _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Pick image error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, dynamic>?> _callRoboflowAPI(Uint8List bytes) async {
    if (_roboflowApiKey == 'YOUR_ROBOFLOW_API_KEY') return _demoDetect(bytes);
    try {
      final base64Image = base64Encode(bytes);
      final uri = Uri.parse(
          'https://detect.roboflow.com/$_roboflowModelId/$_roboflowVersion?api_key=$_roboflowApiKey');
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: base64Image)
          .timeout(const Duration(seconds: 40)); // ✅ เพิ่มจาก 20 → 40 วิ กันเน็ตมือถือช้าโดนตัดก่อนเวลา
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List?;
        if (predictions == null || predictions.isEmpty) return null; // ✅ AI ตรวจสำเร็จแต่ไม่เจอขยะจริงๆ
        final best = predictions.reduce((a, b) =>
            (a['confidence'] as double) > (b['confidence'] as double) ? a : b);
        return {
          'categoryId': _mapClassToCategory(best['class'] as String),
          'label': best['class'],
          'confidence': (best['confidence'] as double) * 100,
        };
      }
      // ✅ HTTP error (เช่น 4xx/5xx) ถือเป็นปัญหาการเชื่อมต่อ ไม่ใช่ "ไม่เจอขยะ"
      throw _ApiConnectionException('HTTP ${response.statusCode}');
    } on TimeoutException {
      debugPrint('Roboflow timeout');
      throw _ApiConnectionException('timeout');
    } on _ApiConnectionException {
      rethrow;
    } catch (e) {
      debugPrint('Roboflow error: $e');
      throw _ApiConnectionException('$e');
    }
  }

  Map<String, dynamic> _demoDetect(Uint8List bytes) {
    final cats = ['recyclable', 'general', 'organic', 'hazardous'];
    final labels = ['plastic', 'general waste', 'organic waste', 'hazardous waste'];
    final idx = DateTime.now().millisecond % 4;
    return {'categoryId': cats[idx], 'label': labels[idx],
        'confidence': 75.0 + (DateTime.now().second % 20).toDouble()};
  }

  Future<void> _saveToHistory(Uint8List bytes, Map<String, dynamic> result,
      double distance, int pointsEarned) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      String imageUrl = '';
      try {
        final ref = FirebaseStorage.instance
            .ref('scan_history/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(bytes);
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('Storage error: $e');
      }

      await FirebaseFirestore.instance.collection('users').doc(uid)
          .collection('scan_history').add({
        'categoryId': result['categoryId'],
        'label': result['label'],
        'confidence': result['confidence'],
        'imageUrl': imageUrl,
        'distanceMeters': distance,
        'pointsEarned': pointsEarned,
        'withinRadius': pointsEarned > 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (pointsEarned > 0) {
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .update({'points': FieldValue.increment(pointsEarned)});
        if (mounted) setState(() => _userPoints += pointsEarned);
      }
    } catch (e) { debugPrint('Save history error: $e'); }
  }

  void _resetScan() {
    setState(() {
      _showResultSheet = false; _detectedCategory = null; _originalCategory = null;
      _imageBytes = null; _confidence = 0; _distanceMeters = -1;
      _withinRadius = false; _pointsEarned = 0; _hasContamination = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]))),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _imageBytes != null && !_showResultSheet
                      ? _buildImagePreview()
                      : _showResultSheet ? const SizedBox.shrink() : _buildScanArea(),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          Expanded(
            child: Center(
              child: Text('scan_waste_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 4),
                Text('$_userPoints ${'points'.tr()}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ป้ายระยะห่างแบบ real-time จากถังขยะที่ใกล้ที่สุด
  Widget _buildLiveDistanceBadge() {
    if (_binPositions.isEmpty) return const SizedBox.shrink();

    final dist = _liveDistanceMeters;
    final within = dist != null && dist <= 6.5;

    String distText;
    if (dist == null) {
      distText = 'scan_locating'.tr();
    } else if (dist >= 1000) {
      distText = '${(dist / 1000).toStringAsFixed(1)} ${'bin_unit_km'.tr()}';
    } else {
      distText = '${dist.toStringAsFixed(1)} ${'bin_unit_m'.tr()}';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: within ? const Color(0xFF2E7D32).withOpacity(0.18) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: within ? const Color(0xFF2E7D32) : Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            within ? Icons.check_circle : Icons.social_distance,
            color: within ? const Color(0xFF66BB6A) : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            within ? 'scan_live_within'.tr() : 'scan_live_distance'.tr(namedArgs: {'dist': distText}),
            style: TextStyle(
              color: within ? const Color(0xFF66BB6A) : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
                borderRadius: BorderRadius.circular(20)),
            child: CustomPaint(
              painter: _ScanFramePainter(),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.document_scanner_outlined, color: Colors.white.withOpacity(0.35), size: 52),
                  const SizedBox(height: 12),
                  Text('scan_tap_to_select'.tr(),
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('scan_instruction'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.6)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text('scan_radius_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5))),
              ],
            ),
          ),
          // ✅ ป้ายระยะห่างแบบ real-time
          _buildLiveDistanceBadge(),
          if (!_binsExist) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                      'ไม่พบจุดถังขยะในระบบ กรุณาเพิ่มจุดถังขยะก่อน',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orange, fontSize: 12, height: 1.5))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: ClipRRect(borderRadius: BorderRadius.circular(20),
            child: Image.memory(_imageBytes!, fit: BoxFit.contain))));
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
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Icon(Icons.photo_library_outlined, color: Colors.white, size: 26),
                  const SizedBox(height: 4),
                  Text('scan_album'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _binsExist ? () => _pickImage(ImageSource.camera) : null,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: _binsExist ? const Color(0xFF2E7D32) : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: (_binsExist ? const Color(0xFF2E7D32) : Colors.grey).withOpacity(0.4),
                      blurRadius: 16, offset: const Offset(0, 4))]),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Icon(Icons.history, color: Colors.white, size: 26),
                  const SizedBox(height: 4),
                  Text('scan_history'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
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
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 3),
            const SizedBox(height: 16),
            Text('scan_analyzing'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('scan_checking_distance'.tr(),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _buildResultSheet() {
    final cat = _detectedCategory!;
    final isOriginalRecyclable = _originalCategory?.id == 'recyclable';

    String distText;
    Color distBg, distBorder, distTextColor, distIconColor;

    if (_distanceMeters < 0) {
      distText = 'scan_no_location'.tr();
      distBg = Colors.grey.shade100; distBorder = Colors.grey;
      distTextColor = Colors.grey; distIconColor = Colors.grey;
    } else if (_withinRadius) {
      distText = 'scan_within_radius'.tr(namedArgs: {'dist': _distanceMeters.toStringAsFixed(1)});
      distBg = const Color(0xFFE8F5E9); distBorder = const Color(0xFF2E7D32);
      distTextColor = const Color(0xFF388E3C); distIconColor = const Color(0xFF2E7D32);
    } else {
      distText = 'scan_out_of_radius'.tr(namedArgs: {'dist': _distanceMeters.toStringAsFixed(1)});
      distBg = const Color(0xFFFFEBEE); distBorder = const Color(0xFFF44336);
      distTextColor = const Color(0xFFB71C1C); distIconColor = const Color(0xFFF44336);
    }

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: distBg, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: distBorder)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.location_on, color: distIconColor, size: 14),
                          const SizedBox(width: 4),
                          Flexible(child: Text(distText,
                              style: TextStyle(fontSize: 11, color: distTextColor, fontWeight: FontWeight.w500))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: _pointsEarned > 0 ? const Color(0xFFFFF9C4) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.stars_rounded,
                            color: _pointsEarned > 0 ? const Color(0xFFF57F17) : Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _pointsEarned > 0
                              ? 'scan_earned_points'.tr(namedArgs: {'points': '$_pointsEarned'})
                              : 'scan_no_points'.tr(),
                          style: TextStyle(
                              fontSize: 12,
                              color: _pointsEarned > 0 ? const Color(0xFFF57F17) : Colors.grey,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              if (!_withinRadius && _distanceMeters >= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200)),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('scan_move_closer'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4))),
                    ]),
                  ),
                ),
              if (_imageBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16),
                        child: Image.memory(_imageBytes!, height: 180, width: double.infinity, fit: BoxFit.cover)),
                    Positioned(
                      bottom: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(cat.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(cat.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          if (_confidence > 0) ...[
                            const SizedBox(width: 6),
                            Text('${_confidence.toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ]),
                      ),
                    ),
                  ]),
                ),
              if (isOriginalRecyclable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasContamination == true ? Colors.red.shade50
                          : _hasContamination == false ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _hasContamination == true ? Colors.red.shade200
                              : _hasContamination == false ? Colors.green.shade200 : Colors.orange.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.help_outline,
                            color: _hasContamination == true ? Colors.red
                                : _hasContamination == false ? Colors.green : Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text('scan_contamination_q'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _hasContamination = false;
                              _detectedCategory = wasteCategories['recyclable'];
                            }),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _hasContamination == false ? Colors.green.shade50 : Colors.white,
                              side: BorderSide(color: _hasContamination == false ? Colors.green : Colors.grey.shade300,
                                  width: _hasContamination == false ? 2 : 1),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('scan_can_clean'.tr(),
                                style: TextStyle(fontSize: 13,
                                    color: _hasContamination == false ? Colors.green.shade700 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _hasContamination = true;
                              _detectedCategory = wasteCategories['general'];
                            }),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _hasContamination == true ? Colors.red.shade50 : Colors.white,
                              side: BorderSide(color: _hasContamination == true ? Colors.red : Colors.grey.shade300,
                                  width: _hasContamination == true ? 2 : 1),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('scan_cannot_clean'.tr(),
                                style: TextStyle(fontSize: 13,
                                    color: _hasContamination == true ? Colors.red.shade700 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ]),
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
                        backgroundColor: cat.color, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: Text('scan_next'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          color: cat.lightColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cat.color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.delete_outline, color: cat.color, size: 18),
          const SizedBox(width: 6),
          Text('scan_bin_color'.tr(namedArgs: {'color': cat.binColor}),
              style: TextStyle(color: cat.color, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        if (cat.examples.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('scan_examples_label'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4,
              children: cat.examples.map((e) => _buildTag(e, cat.color)).toList()),
        ],
        if (cat.disposal.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('scan_disposal_label'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ...cat.disposal.map((d) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle, color: cat.color, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(d, style: const TextStyle(fontSize: 12))),
            ]),
          )),
        ],
        if (cat.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('scan_notes_label'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ...cat.notes.map((n) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                cat.notesAreWarnings ? Icons.cancel : Icons.info_outline,
                color: cat.notesAreWarnings ? Colors.red : Colors.orange,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(n, style: const TextStyle(fontSize: 12))),
            ]),
          )),
        ],
        if (cat.prices.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.storefront_outlined, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text('scan_price_label'.tr(),
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ...cat.prices.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(color: Colors.amber, fontSize: 12)),
                  Expanded(child: Text(p, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                ]),
              )),
            ]),
          ),
        ],
        if (cat.disposalNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cat.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline, color: cat.color, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(cat.disposalNote, style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildNoDetectionSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.search_off, color: Colors.orange, size: 32),
          ),
          const SizedBox(height: 14),
          Text('scan_no_waste'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('scan_no_waste_hint'.tr(), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('scan_select_album'.tr()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _resetScan,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text('scan_retry'.tr()),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BinResult {
  final double distanceMeters;
  final bool withinRadius;
  const _BinResult({required this.distanceMeters, required this.withinRadius});
}

// ✅ ใช้แยกกรณี "เชื่อมต่อ/timeout ไม่สำเร็จ" ออกจากกรณี "AI ตรวจแล้วไม่เจอขยะจริงๆ"
class _ApiConnectionException implements Exception {
  final String message;
  _ApiConnectionException(this.message);
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 3
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const len = 28.0; const r = 10.0;
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + len), paint);
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawLine(Offset(0, size.height - r - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r - len), Offset(size.width, size.height - r), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}