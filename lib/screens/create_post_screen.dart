import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'app_theme.dart';

const int kMaxPostImages = 6;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // ✅ รองรับหลายรูป (แบบ Facebook/Instagram) แทนรูปเดียวแบบเดิม
  final List<Uint8List> _selectedImages = [];
  bool _isLoading = false;
  int _currentPreviewIndex = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= kMaxPostImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('post_max_images'.tr(namedArgs: {'max': '$kMaxPostImages'}))),
      );
      return;
    }
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;

      final remaining = kMaxPostImages - _selectedImages.length;
      final toAdd = picked.take(remaining).toList();

      for (final file in toAdd) {
        final bytes = await file.readAsBytes();
        _selectedImages.add(bytes);
      }
      if (mounted) setState(() {});

      if (picked.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('post_max_images'.tr(namedArgs: {'max': '$kMaxPostImages'}))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    }
  }

  Future<void> _pickSingleFromCamera() async {
    if (kIsWeb) return; // กล้องบนเว็บใช้ pickImage แบบอื่น ข้ามไปเพื่อความง่าย
    if (_selectedImages.length >= kMaxPostImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('post_max_images'.tr(namedArgs: {'max': '$kMaxPostImages'}))),
      );
      return;
    }
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _selectedImages.add(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_currentPreviewIndex >= _selectedImages.length) {
        _currentPreviewIndex = _selectedImages.isEmpty ? 0 : _selectedImages.length - 1;
      }
    });
  }

  Future<void> _uploadPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('title_required'.tr())),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('description_required'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ แปลงทุกรูปเป็น base64 เก็บเป็น List
      final List<String> imagesBase64 = _selectedImages
          .map((bytes) => base64Encode(bytes))
          .toList();

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'User not logged in';
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'unknown'.tr();
      final userProfileImage = userDoc.data()?['profileImage'] ?? '';

      final postData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        // ✅ ฟิลด์ใหม่: เก็บรูปหลายรูป
        'images': imagesBase64,
        // ✅ เก็บฟิลด์เดิมไว้ด้วยเพื่อความเข้ากันได้กับโค้ดเก่า/โพสต์เก่า (ใช้รูปแรกเป็นตัวแทน)
        'imageBase64': imagesBase64.isNotEmpty ? imagesBase64.first : '',
        'userId': currentUser.uid,
        'userName': userName,
        'userProfileImage': userProfileImage,
        'createdAt': Timestamp.now(),
        'likes': 0,
        'commentCount': 0,
      };

      await _firestore.collection('community_posts').add(postData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('post_created_success'.tr()), backgroundColor: kPrimaryGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'create_post'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // ✂️ เอาส่วน actions: [...] ออกเรียบร้อยแล้ว
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ การ์ดรวมข้อมูลโพสต์ ดีไซน์โมเดิร์นขึ้น
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    maxLines: null,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'enter_post_title'.tr(),
                      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'enter_post_description'.tr(),
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ ตัวเลือกรูปภาพ แบบแกลเลอรี IG/FB
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: kPrimaryGreen, size: 20),
                          const SizedBox(width: 8),
                          Text('post_image_label'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      if (_selectedImages.isNotEmpty)
                        Text(
                          '${_selectedImages.length}/$kMaxPostImages',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // แสดง preview รูปแรกใหญ่ๆ พร้อม indicator ถ้ามีหลายรูป (สไตล์ IG)
                  if (_selectedImages.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ScrollConfiguration(
                              behavior: MouseDragScrollBehavior(),
                              child: PageView.builder(
                                itemCount: _selectedImages.length,
                                onPageChanged: (i) => setState(() => _currentPreviewIndex = i),
                                itemBuilder: (context, i) => Image.memory(_selectedImages[i], fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () => _removeImage(_currentPreviewIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            if (_selectedImages.length > 1)
                              Positioned(
                                bottom: 10,
                                left: 0, right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_selectedImages.length, (i) {
                                    final active = i == _currentPreviewIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: active ? 18 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: active ? Colors.white : Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // แถบ thumbnail เล็กๆ ให้แตะสลับรูป + ปุ่มเพิ่มรูป
                    SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (int i = 0; i < _selectedImages.length; i++)
                            GestureDetector(
                              onTap: () => setState(() => _currentPreviewIndex = i),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: i == _currentPreviewIndex ? kPrimaryGreen : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(_selectedImages[i], fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          if (_selectedImages.length < kMaxPostImages)
                            GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                width: 64,
                                decoration: BoxDecoration(
                                  color: kAccentGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kAccentGreen),
                                ),
                                child: const Icon(Icons.add, color: kPrimaryGreen),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: kAccentGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kAccentGreen, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 42, color: kPrimaryGreen),
                            const SizedBox(height: 10),
                            Text('tap_to_select_image'.tr(),
                                style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('post_multi_image_hint'.tr(namedArgs: {'max': '$kMaxPostImages'}),
                                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          ],
                        ),
                      ),
                    ),

                  if (!kIsWeb && _selectedImages.isNotEmpty && _selectedImages.length < kMaxPostImages) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _pickSingleFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined, color: kDarkGreen, size: 18),
                      label: Text('post_take_photo'.tr(), style: const TextStyle(color: kDarkGreen)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ ปุ่มส่งโพสต์ด้านล่าง
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _uploadPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'post_submit_button'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}