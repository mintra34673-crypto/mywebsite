import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http; // แก้เส้นแดง: ต้องมีตัวนี้เพื่อส่งรูป
import 'dart:convert'; // แก้เส้นแดง: ต้องมีตัวนี้เพื่ออ่านค่า URL ที่ตอบกลับมา
import 'package:image_picker/image_picker.dart'; // แก้เส้นแดง: ต้องมีตัวนี้เพื่อเลือกรูป
import 'package:image/image.dart' as img; // ✅ ใช้ครอปรูปเป็นสี่เหลี่ยมจัตุรัสอัตโนมัติ (ทำงานได้ทั้งเว็บ/มือถือ)
import 'app_theme.dart';

class EditInformationScreen extends StatefulWidget {
  const EditInformationScreen({super.key});

  @override
  State<EditInformationScreen> createState() => _EditInformationScreenState();
}

class _EditInformationScreenState extends State<EditInformationScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Uint8List? _imageBytes; // ✅ เปลี่ยนจาก File → bytes เพื่อให้ทำงานถูกต้องบน Flutter Web ด้วย
  String? _currentImageUrl; // ตัวแปรเก็บ URL รูปปัจจุบันจากฐานข้อมูล
  bool _isLoading = false;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ดึงข้อมูลเก่ามาโชว์ในช่องกรอก
  void _loadUserData() async {
    if (user == null) return;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (doc.exists) {
      setState(() {
        nameController.text = doc['name'] ?? "";
        phoneController.text = doc['phone'] ?? "";
        _currentImageUrl = doc['profileImage'];
      });
    }
  }

  //  เลือกรูปจากเครื่อง แล้วครอปเป็นสี่เหลี่ยมจัตุรัสจากกึ่งกลางอัตโนมัติ
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedFile == null) return;

    setState(() => _isCropping = true);
    try {
      final rawBytes = await pickedFile.readAsBytes();
      final cropped = await compute(_cropSquareIsolate, rawBytes);
      if (mounted) {
        setState(() {
          _imageBytes = cropped;
          _isCropping = false;
        });
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) setState(() => _isCropping = false);
    }
  }

  //  ครอปรูปเป็นสี่เหลี่ยมจัตุรัสจากกึ่งกลาง + ย่อขนาดให้พอดีกับ avatar
  static Uint8List _cropSquareIsolate(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final offsetX = (decoded.width - side) ~/ 2;
    final offsetY = (decoded.height - side) ~/ 2;

    final cropped = img.copyCrop(decoded, x: offsetX, y: offsetY, width: side, height: side);
    final resized = img.copyResize(cropped, width: 500, height: 500);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  // ฟังก์ชันอัปโหลดไป Cloudinary และบันทึกลง Firestore
  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      String? finalImageUrl = _currentImageUrl;

      if (_imageBytes != null) {
        // --- ส่วนส่งรูปไป Cloudinary ---
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/dggonusoa/image/upload'),
        );

        // **สำคัญ: เปลี่ยน 'YOUR_PRESET' เป็นชื่อที่คุณตั้งใน Cloudinary (แบบ Unsigned)**
        request.fields['upload_preset'] = 'my_preset';
        request.files.add(
          http.MultipartFile.fromBytes('file', _imageBytes!, filename: 'profile.jpg'),
        );

        var response = await request.send();
        var responseString = await response.stream.bytesToString();
        var jsonRes = jsonDecode(responseString);

        if (jsonRes['secure_url'] != null) {
          finalImageUrl = jsonRes['secure_url'];
        }
      }

      // --- บันทึกข้อมูลลง Firestore ---
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'profileImage': finalImageUrl,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_successful'.tr()), backgroundColor: kPrimaryGreen),
        );
        Navigator.pop(context); // กลับไปหน้า Profile
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('update_error'.tr(args: [e.toString()]))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'edit_information'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'edit_profile'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ส่วนคลิกเพื่อเปลี่ยนรูป (ครอปสี่เหลี่ยมจัตุรัสอัตโนมัติ)
                  Center(
                    child: GestureDetector(
                      onTap: _isCropping ? null : _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (_currentImageUrl != null
                                        ? NetworkImage(_currentImageUrl!)
                                        : null) as ImageProvider?,
                            child: _isCropping
                                ? const CircularProgressIndicator(color: kPrimaryGreen)
                                : (_imageBytes == null && _currentImageUrl == null)
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      )
                                    : null,
                          ),
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: kPrimaryGreen,
                              radius: 18,
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'edit_photo_crop_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 30),

                  // ช่องกรอกข้อมูล
                  _buildTextField(
                    'full_name'.tr(),
                    nameController,
                    Icons.person_outline,
                  ),
                  _buildTextField(
                    'email'.tr(),
                    TextEditingController(text: user?.email),
                    Icons.email_outlined,
                    enabled: false,
                  ),
                  _buildTextField(
                    'phone_number'.tr(),
                    phoneController,
                    Icons.phone_android_outlined,
                  ),

                  const SizedBox(height: 40),

                  // ปุ่มอัปเดต
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        minimumSize: const Size(200, 50),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _handleUpdate,
                      child: Text(
                        'update'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
  }) {
    final borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        enabled: enabled,
        cursorColor: kPrimaryGreen,
        style: TextStyle(color: enabled ? Colors.black87 : Colors.grey.shade600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: enabled ? kDarkGreen : Colors.grey),
          prefixIcon: Icon(icon, color: enabled ? kPrimaryGreen : Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
          border: borderStyle,
          enabledBorder: borderStyle,
          disabledBorder: borderStyle,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }
}