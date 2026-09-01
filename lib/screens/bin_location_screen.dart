import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

enum BinType { all, general, recycle, organic, hazardous }

extension BinTypeExt on BinType {
  String get label {
    switch (this) {
      case BinType.all: return 'bin_filter_all'.tr();
      case BinType.general: return 'bintype_general'.tr();
      case BinType.recycle: return 'bintype_recycle'.tr();
      case BinType.organic: return 'bintype_organic'.tr();
      case BinType.hazardous: return 'bintype_hazardous'.tr();
    }
  }

  Color get color {
    switch (this) {
      case BinType.all: return Colors.grey;
      case BinType.general: return kPrimaryGreen;
      case BinType.recycle: return kLightGreen;
      case BinType.organic: return kAccentGreen;
      case BinType.hazardous: return const Color(0xFFFF9800);
    }
  }

  IconData get icon {
    switch (this) {
      case BinType.all: return Icons.delete_outline;
      case BinType.general: return Icons.delete_outline;
      case BinType.recycle: return Icons.recycling;
      case BinType.organic: return Icons.eco_outlined;
      case BinType.hazardous: return Icons.warning_amber_outlined;
    }
  }
}

// หมายเหตุ: ใช้เทียบกับค่าที่เก็บใน Firestore (เก็บเป็นภาษาไทยเดิม)
// เพื่อไม่กระทบข้อมูลเก่าใน DB จึงยังแมพจาก string ไทยเหมือนเดิม
BinType binTypeFromString(String? s) {
  switch (s) {
    case 'รีไซเคิล': return BinType.recycle;
    case 'อินทรีย์': return BinType.organic;
    case 'อันตราย': return BinType.hazardous;
    default: return BinType.general;
  }
}

class BinData {
  final String id;
  final String name;
  final BinType type;
  final List<BinType> types;
  final LatLng position;
  final String addedBy;
  final String? addedByUid;
  final DateTime? lastUpdate;
  final String? imageUrl;

  BinData({
    required this.id,
    required this.name,
    required this.type,
    required this.types,
    required this.position,
    required this.addedBy,
    this.addedByUid,
    this.lastUpdate,
    this.imageUrl,
  });

  factory BinData.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<BinType> typeList = [];
    if (d['types'] != null && d['types'] is List) {
      typeList = (d['types'] as List).map((t) => binTypeFromString(t as String?)).toList();
    } else if (d['type'] != null) {
      typeList = (d['type'] as String).split(',').map((t) => binTypeFromString(t.trim())).toList();
    }
    if (typeList.isEmpty) typeList = [BinType.general];

    return BinData(
      id: doc.id,
      name: d['name'] ?? 'bin_default_name'.tr(),
      type: typeList.first,
      types: typeList,
      position: LatLng(
        (d['lat'] as num?)?.toDouble() ?? 0.0,
        (d['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      addedBy: d['addedBy'] ?? 'bin_no_name'.tr(),
      addedByUid: d['addedByUid'],
      lastUpdate: (d['lastUpdate'] as Timestamp?)?.toDate(),
      imageUrl: d['imageUrl'],
    );
  }
}

class BinLocationScreen extends StatefulWidget {
  const BinLocationScreen({super.key});

  @override
  State<BinLocationScreen> createState() => _BinLocationScreenState();
}

class _BinLocationScreenState extends State<BinLocationScreen> {
  LatLng? _userLocation;
  LatLng? _pendingLocation;
  bool _didInitialZoom = false;
  bool _mapReady = false;
  bool _locating = true;
  String? _selectedBinId;
  BinType _selectedFilter = BinType.all;
  List<BinData> _bins = [];
  List<BinData> _filteredBins = [];
  bool _loadingBins = true;
  final TextEditingController _searchController = TextEditingController();

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _listenBins();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      // ✨ ขอตำแหน่งปัจจุบันเร็วๆ ก่อน 1 ครั้ง (accuracy กลาง + timeout กันรอนานเกินไป) แล้วซูมแผนที่ไปหาทันที
      try {
        final current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        final firstLocation = LatLng(current.latitude, current.longitude);
        if (mounted) {
          setState(() {
            _userLocation = firstLocation;
            _locating = false;
          });
          _tryInitialZoom();
        }
      } catch (e) {
        debugPrint('❌ getCurrentPosition error: $e');
        if (mounted) setState(() => _locating = false);
      }

      // ✨ Stream ตำแหน่งแบบ real-time - อัพเดตทุก 10 เมตร + check ก่อน setState
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          if (_userLocation == null ||
              _userLocation!.latitude != newLocation.latitude ||
              _userLocation!.longitude != newLocation.longitude) {
            setState(() {
              _userLocation = newLocation;
              _locating = false;
            });
            _tryInitialZoom();
          }
        }
      }, onError: (e) {
        debugPrint('❌ Location stream error: $e');
      });
    } catch (e) {
      debugPrint('❌ Permission error: $e');
    }
  }

  void _listenBins() {
    FirebaseFirestore.instance.collection('bins').snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _bins = snap.docs.map((d) => BinData.fromFirestore(d)).toList();
          _loadingBins = false;
          _applyFilters();
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loadingBins = false);
    });
  }

  void _applyFilters() {
    List<BinData> result = _bins;

    if (_selectedFilter != BinType.all) {
      result = result.where((b) => b.types.contains(_selectedFilter)).toList();
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      result = result.where((b) => b.name.toLowerCase().contains(query)).toList();
    }

    setState(() => _filteredBins = result);
  }

  void _performSearch() {
    _applyFilters();
  }

  void _zoomToLocation(BinData bin) {
    setState(() => _selectedBinId = bin.id);
    _mapController.move(bin.position, 17.0);
  }

  // ✨ ซูมไปตำแหน่งผู้ใช้ได้ก็ต่อเมื่อแผนที่ mount เสร็จแล้ว (onMapReady) และมีตำแหน่งแล้วเท่านั้น
  // ป้องกัน error "FlutterMap widget has not been rendered yet" ที่ทำให้ move() เงียบๆ ไม่ทำงาน
  void _tryInitialZoom() {
    if (_didInitialZoom || !_mapReady || _userLocation == null) return;
    _didInitialZoom = true;
    _mapController.move(_userLocation!, 17.0);
  }

  String _formatDistance(BinData bin) {
    if (_userLocation == null) return '';
    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude, _userLocation!.longitude,
      bin.position.latitude, bin.position.longitude,
    );
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} ${'bin_unit_km'.tr()}';
    return '${meters.toInt()} ${'bin_unit_m'.tr()}';
  }

  bool _isOwner(BinData bin) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && bin.addedByUid == currentUser.uid;
  }

  void _showBinDetail(BinData bin) {
    setState(() => _selectedBinId = bin.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BinDetailSheet(
        bin: bin,
        distance: _formatDistance(bin),
        isOwner: _isOwner(bin),
        onEdited: () {
          if (mounted) setState(() => _applyFilters());
        },
      ),
    );
  }

  void _showAddBin() {
    final targetLocation = _pendingLocation ?? _userLocation;
    if (targetLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_finding_location'.tr())));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBinSheet(userLocation: targetLocation),
    ).then((_) {
      if (mounted) setState(() => _pendingLocation = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultCenter = _userLocation ?? const LatLng(18.7883, 98.9853);

    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        title: Text('bin_location_title'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 15.0,
              onMapReady: () {
                _mapReady = true;
                _tryInitialZoom();
              },
              onTap: (tapPosition, point) => setState(() => _pendingLocation = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.binsort_new',
              ),
              if (_selectedBinId != null)
                CircleLayer(
                  circles: [
                    for (final bin in _bins)
                      if (bin.id == _selectedBinId)
                        CircleMarker(
                          point: bin.position,
                          radius: 6,
                          useRadiusInMeter: true,
                          color: bin.type.color.withOpacity(0.3),
                          borderColor: bin.type.color,
                          borderStrokeWidth: 3,
                        ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 64, height: 64,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimaryGreen.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(child: Icon(Icons.my_location, color: kPrimaryGreen, size: 36)),
                      ),
                    ),
                  if (_pendingLocation != null)
                    Marker(
                      point: _pendingLocation!,
                      width: 48, height: 48,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 42),
                    ),
                  ..._filteredBins.map((bin) => Marker(
                    point: bin.position,
                    width: 50, height: 50,
                    child: GestureDetector(
                      onTap: () => _showBinDetail(bin),
                      child: _BinMarker(type: bin.type),
                    ),
                  )),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12, left: 12, right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'bin_search_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _performSearch();
                          },
                          child: const Icon(Icons.close, color: Colors.grey, size: 18),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty && _filteredBins.isNotEmpty)
            Positioned(
              top: 60, left: 12, right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredBins.length,
                  itemBuilder: (ctx, idx) {
                    final bin = _filteredBins[idx];
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedBinId = bin.id);
                        _zoomToLocation(bin);
                        _searchController.clear();
                        _performSearch();
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(bin.type.icon, color: bin.type.color, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bin.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  Text(bin.addedBy, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [BinType.all, BinType.general, BinType.recycle, BinType.organic, BinType.hazardous].map((t) {
                  final selected = _selectedFilter == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedFilter = t);
                        _applyFilters();
                      },
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
                            Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : t.color)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Positioned(
            bottom: 60, right: 16,
            child: FloatingActionButton(
              backgroundColor: _pendingLocation != null ? Colors.red : kPrimaryGreen,
              onPressed: _showAddBin,
              child: Icon(_pendingLocation != null ? Icons.add_location : Icons.add, color: Colors.white, size: 28),
            ),
          ),
          if (_pendingLocation != null)
            Positioned(
              bottom: 125, left: 16, right: 70,
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
                    Expanded(child: Text('bin_pending_hint'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                    GestureDetector(
                      onTap: () => setState(() => _pendingLocation = null),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (_locating)
            Positioned(
              top: 70, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryGreen),
                      ),
                      const SizedBox(width: 8),
                      Text('bin_finding_location'.tr(), style: const TextStyle(fontSize: 12, color: kDarkGreen, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          if (_loadingBins) const Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
        ],
      ),
    );
  }
}

class _BinMarker extends StatelessWidget {
  final BinType type;
  const _BinMarker({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
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

class _BinDetailSheet extends StatelessWidget {
  final BinData bin;
  final String distance;
  final bool isOwner;
  final VoidCallback onEdited;

  const _BinDetailSheet({
    required this.bin,
    required this.distance,
    required this.isOwner,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final lastUpdateStr = bin.lastUpdate != null ? DateFormat('dd MMM yyyy').format(bin.lastUpdate!) : 'bin_today'.tr();

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            if (bin.imageUrl != null && bin.imageUrl!.isNotEmpty) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: bin.imageUrl!.startsWith('data:image')
                        ? Image.memory(base64Decode(bin.imageUrl!.split(',').last), height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                        : Image.network(bin.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                  if (isOwner)
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => _deleteImage(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.delete, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bin.type.color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(bin.type.icon, color: bin.type.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bin.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: bin.types.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: t.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text(t.label, style: TextStyle(fontSize: 12, color: t.color, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                if (distance.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 2),
                    Text(distance, style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ]),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_outline, label: 'bin_added_by'.tr(), value: bin.addedBy),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.update, label: 'bin_last_update'.tr(), value: lastUpdateStr),
            if (isOwner) ...[
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.verified_user, label: 'bin_status'.tr(), value: '✅ ${'bin_owner_status'.tr()}'),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.grey)),
                    child: Text('bin_close'.tr(), style: const TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${bin.position.latitude},${bin.position.longitude}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.navigation_outlined, color: Colors.white, size: 18),
                    label: Text('bin_navigate'.tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditSheet(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: kDarkGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                      label: Text('bin_edit'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('bin_delete_image_title'.tr()),
        content: Text('bin_delete_image_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('bin_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('bins').doc(bin.id).update({'imageUrl': ''});
                onEdited();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${'bin_delete_success'.tr()}')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'bin_error'.tr()}: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('bin_delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBinSheet(bin: bin, onUpdated: onEdited),
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
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _EditBinSheet extends StatefulWidget {
  final BinData bin;
  final VoidCallback onUpdated;
  const _EditBinSheet({required this.bin, required this.onUpdated});

  @override
  State<_EditBinSheet> createState() => _EditBinSheetState();
}

class _EditBinSheetState extends State<_EditBinSheet> {
  late TextEditingController _nameController;
  Uint8List? _pickedBytes;
  String? _base64Image;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bin.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, imageQuality: 20, maxWidth: 400, maxHeight: 400);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      if (bytes.lengthInBytes > 60 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_image_too_large'.tr())));
        return;
      }
      setState(() {
        _pickedBytes = bytes;
        _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_name_required'.tr())));
      return;
    }

    setState(() => _updating = true);

    try {
      final updates = <String, dynamic>{
        'name': newName,
        'lastUpdate': Timestamp.now(),
      };
      if (_base64Image != null) {
        updates['imageUrl'] = _base64Image!;
      }

      await FirebaseFirestore.instance.collection('bins').doc(widget.bin.id).update(updates);

      widget.onUpdated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_base64Image != null ? '✅ ${'bin_update_success'.tr()}' : '✅ ${'bin_update_name_success'.tr()}'),
          backgroundColor: kPrimaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'bin_error'.tr()}: $e')));
      }
    }
  }

  Future<void> _deleteBin() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('bin_delete_bin_title'.tr()),
        content: Text('${'bin_delete_bin_confirm'.tr()} "${widget.bin.name}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('bin_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _updating = true);

              try {
                await FirebaseFirestore.instance.collection('bins').doc(widget.bin.id).delete();

                widget.onUpdated();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ ${'bin_delete_bin_success'.tr()}'),
                    backgroundColor: kPrimaryGreen,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _updating = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'bin_error'.tr()}: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('bin_delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.edit_outlined, color: kDarkGreen),
                const SizedBox(width: 8),
                Text('bin_edit_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                enabled: !_updating,
                decoration: InputDecoration(
                  hintText: 'bin_name_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text('📸 ${'bin_change_image'.tr()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _updating ? null : _pickImage,
                child: Container(
                  height: _pickedBytes != null ? 140 : 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: _pickedBytes != null
                      ? Stack(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity, height: 140)),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                decoration: BoxDecoration(color: kPrimaryGreen, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.check, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey[600], size: 28),
                            const SizedBox(height: 6),
                            Text('bin_tap_change_image'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            if (widget.bin.imageUrl != null && widget.bin.imageUrl!.isNotEmpty)
                              Text('bin_has_current_image'.tr(), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _updating ? null : _updateName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _updating ? Colors.grey[300] : kPrimaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _updating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: Text(_updating ? 'bin_saving'.tr() : '✅ ${'bin_save_edit'.tr()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  onPressed: _updating ? null : _deleteBin,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  label: Text('bin_delete_bin_button'.tr(), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddBinSheet extends StatefulWidget {
  final LatLng userLocation;
  const _AddBinSheet({required this.userLocation});

  @override
  State<_AddBinSheet> createState() => _AddBinSheetState();
}

class _AddBinSheetState extends State<_AddBinSheet> {
  final _nameController = TextEditingController();
  final Set<BinType> _selectedTypes = {BinType.general};
  Uint8List? _pickedBytes;
  String? _base64Image;
  bool _uploading = false;
  String _uploadStatus = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, imageQuality: 20, maxWidth: 400, maxHeight: 400);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      if (bytes.lengthInBytes > 60 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_image_too_large'.tr())));
        return;
      }
      setState(() {
        _pickedBytes = bytes;
        _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_name_required'.tr()))); return; }
    if (_selectedTypes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('bin_type_required'.tr()))); return; }

    setState(() { _uploading = true; _uploadStatus = 'bin_saving_data'.tr(); });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = user != null ? await FirebaseFirestore.instance.collection('users').doc(user.uid).get() : null;
      final displayName = userDoc?.data()?['name'] ?? user?.displayName ?? 'bin_no_name'.tr();
      final typeList = _selectedTypes.map((t) => t.label).toList();

      await FirebaseFirestore.instance.collection('bins').add({
        'name': name,
        'type': typeList.length == 1 ? typeList.first : typeList.join(', '),
        'types': typeList,
        'lat': widget.userLocation.latitude,
        'lng': widget.userLocation.longitude,
        'addedBy': displayName,
        'addedByUid': user?.uid,
        'lastUpdate': Timestamp.now(),
        'imageUrl': _base64Image ?? '',
      });

      if (user != null) {
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': user.uid, 'type': 'add_bin', 'title': 'bin_activity_added'.tr(),
          'detail': name, 'binTypes': typeList, 'points': 1, 'timestamp': Timestamp.now(),
        });
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'points': FieldValue.increment(1)});
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${'bin_add_success'.tr()}'), backgroundColor: kPrimaryGreen));
      }
    } catch (e) {
      if (mounted) { setState(() => _uploading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'bin_error'.tr()}: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.add_location_alt_outlined, color: kPrimaryGreen),
                  const SizedBox(width: 8),
                  Text('bin_add_new'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kPrimaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.star, color: kPrimaryGreen, size: 14),
                      const SizedBox(width: 4),
                      Text('bin_get_points'.tr(), style: const TextStyle(fontSize: 12, color: kPrimaryGreen, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('bin_when_success'.tr(), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'bin_name_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  filled: true, fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [BinType.general, BinType.recycle, BinType.organic, BinType.hazardous].map((t) {
                  final sel = _selectedTypes.contains(t);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() { if (sel) _selectedTypes.remove(t); else _selectedTypes.add(t); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: sel ? t.color : t.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.color, width: sel ? 0 : 1)),
                          child: Column(children: [
                            if (sel) const Icon(Icons.check_circle, color: Colors.white, size: 18) else Icon(t.icon, color: t.color, size: 18),
                            const SizedBox(height: 2),
                            Text(t.label, style: TextStyle(fontSize: 10, color: sel ? Colors.white : t.color, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: _pickedBytes != null ? 120 : 50,
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!, width: 1)),
                  child: _pickedBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity, height: 120))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 18),
                          const SizedBox(width: 8),
                          Text('bin_photo_optional'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        ]),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _uploading ? Colors.grey[300] : kPrimaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: Text(_uploading ? (_uploadStatus.isNotEmpty ? _uploadStatus : 'bin_saving_short'.tr()) : ' ${'bin_add_new_button'.tr()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}