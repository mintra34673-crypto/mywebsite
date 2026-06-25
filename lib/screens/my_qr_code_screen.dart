import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart'; // ใช้ตัวนี้แทน ImageGallerySaver

class MyQrCodeScreen extends StatefulWidget {
  const MyQrCodeScreen({super.key});

  @override
  State<MyQrCodeScreen> createState() => _MyQrCodeScreenState();
}

class _MyQrCodeScreenState extends State<MyQrCodeScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text(
          'my_qr_code'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFE0E0),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Screenshot(
              controller: screenshotController,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: userId ?? 'unknown_user_id'.tr(),
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- แก้ไขปุ่มโหลดตรงนี้ ---
                _buildActionButton(Icons.file_download_outlined, () async {
                  final Uint8List? image = await screenshotController.capture();
                  if (image != null) {
                    // 1. บันทึกไฟล์ลง Temporary Directory ก่อน
                    final directory = await getTemporaryDirectory();
                    final imagePath = '${directory.path}/qr_save.png';
                    final file = File(imagePath);
                    await file.writeAsBytes(image);

                    // 2. ใช้ Gal บันทึกลงอัลบั้มภาพ
                    await Gal.putImage(imagePath);

                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('qr_saved'.tr())));
                    }
                  }
                }),
                const SizedBox(width: 40),
                // --- ปุ่มแชร์ภาพ ---
                _buildActionButton(Icons.share_outlined, () async {
                  final Uint8List? image = await screenshotController.capture();
                  if (image != null) {
                    final directory =
                        await getTemporaryDirectory(); // ใช้ Temp ดีกว่าป้องกันไฟล์ค้าง
                    final imagePath = '${directory.path}/my_qr_share.png';
                    final file = File(imagePath);
                    await file.writeAsBytes(image);

                    await Share.shareXFiles([
                      XFile(imagePath),
                    ], text: 'share_qr_message'.tr());
                  }
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}
