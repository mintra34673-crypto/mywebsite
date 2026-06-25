import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http; // แก้เส้นแดง: ต้องมีตัวนี้เพื่อส่งรูป
import 'dart:convert'; // แก้เส้นแดง: ต้องมีตัวนี้เพื่ออ่านค่า URL ที่ตอบกลับมา
import 'package:image_picker/image_picker.dart'; // แก้เส้นแดง: ต้องมีตัวนี้เพื่อเลือกรูป
import 'dart:io';

class EditInformationScreen extends StatefulWidget {
  const EditInformationScreen({super.key});

  @override
  State<EditInformationScreen> createState() => _EditInformationScreenState();
}

class _EditInformationScreenState extends State<EditInformationScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  File? _imageFile; // ตัวแปรเก็บไฟล์รูปที่เลือก
  String? _currentImageUrl; // ตัวแปรเก็บ URL รูปปัจจุบันจากฐานข้อมูล
  bool _isLoading = false;

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

  // ฟังก์ชันเลือกรูปจากเครื่อง
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // ฟังก์ชันอัปโหลดไป Cloudinary และบันทึกลง Firestore
  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      String? finalImageUrl = _currentImageUrl;

      if (_imageFile != null) {
        // --- ส่วนส่งรูปไป Cloudinary ---
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/dggonusoa/image/upload'),
        );

        // **สำคัญ: เปลี่ยน 'YOUR_PRESET' เป็นชื่อที่คุณตั้งใน Cloudinary (แบบ Unsigned)**
        request.fields['upload_preset'] = 'my_preset';
        request.files.add(
          await http.MultipartFile.fromPath('file', _imageFile!.path),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('update_successful'.tr())));
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
      backgroundColor: const Color(0xFFFFF9E3), // สีพื้นหลังตามดีไซน์
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'edit_information'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'edit_profile'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ส่วนคลิกเพื่อเปลี่ยนรูป
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (_currentImageUrl != null
                                        ? NetworkImage(_currentImageUrl!)
                                        : null)
                                    as ImageProvider?,
                          child:
                              (_imageFile == null && _currentImageUrl == null)
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
                            backgroundColor: Color(0xFFD4B996),
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5D6A7),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
