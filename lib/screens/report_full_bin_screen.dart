import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ReportFullBinScreen extends StatefulWidget {
  final String binId;
  const ReportFullBinScreen({super.key, required this.binId});

  @override
  State<ReportFullBinScreen> createState() => _ReportFullBinScreenState();
}

class _ReportFullBinScreenState extends State<ReportFullBinScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

Future<void> _handleReport() async {
  final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
  if (photo == null) return;

  setState(() => _isLoading = true);
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  try {
    final binDoc = FirebaseFirestore.instance
        .collection('bins')
        .doc(widget.binId);
    final snapshot = await binDoc.get();

    List reportedUsers = snapshot.data()?['reportedUsers'] ?? [];

    if (reportedUsers.contains(uid)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('already_reported'.tr())),
        );
      return;
    }

    if ((snapshot.data()?['reportCount'] ?? 0) >= 5) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('bin_already_confirmed_full'.tr())),
        );
      return;
    }

    // ✅ update ครั้งเดียว รวม lastUpdate ไว้ด้วย
    await binDoc.update({
      'reportCount': FieldValue.increment(1),
      'reportedUsers': FieldValue.arrayUnion([uid]),
      'lastUpdate': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('report_success'.tr())),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_occurred'.tr(args: [e.toString()]))),
      );
  } finally {
    setState(() => _isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text('report_full_bin'.tr()),
        backgroundColor: const Color(0xFFFFE4E1),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    size: 80,
                    color: Color(0xFFD4B996),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'take_photo'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _handleReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B996),
                    ),
                    child: Text(
                      'take_photo'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
