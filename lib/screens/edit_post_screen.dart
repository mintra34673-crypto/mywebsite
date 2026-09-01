import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'app_theme.dart';

const int kMaxEditPostImages = 6;

/// รูปภาพในโพสต์ระหว่างแก้ไข: แยกว่าเป็นรูปเดิม (base64 string จาก Firestore)
/// หรือรูปใหม่ที่เพิ่งเลือก (bytes ที่ยังไม่ได้อัปโหลด)
class _EditableImage {
  final String? existingBase64; // ถ้าเป็นรูปเดิม
  final Uint8List? newBytes; // ถ้าเป็นรูปใหม่ที่เพิ่งเลือก

  _EditableImage.existing(this.existingBase64) : newBytes = null;
  _EditableImage.fresh(this.newBytes) : existingBase64 = null;

  Uint8List get displayBytes =>
      newBytes ?? base64Decode(existingBase64 ?? '');

  String toBase64() => newBytes != null ? base64Encode(newBytes!) : (existingBase64 ?? '');
}

class EditPostScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.postId, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final ImagePicker _imagePicker = ImagePicker();

  final List<_EditableImage> _images = [];
  bool _isLoading = false;
  int _currentPreviewIndex = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.post['description'] ?? '');

    // โหลดรูปเดิม: รองรับทั้งโพสต์ใหม่ (images list) และโพสต์เก่า (imageBase64 เดี่ยว)
    final rawImages = widget.post['images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      for (final img in rawImages.whereType<String>()) {
        if (img.isNotEmpty) _images.add(_EditableImage.existing(img));
      }
    } else {
      final legacy = widget.post['imageBase64'];
      if (legacy != null && legacy.toString().isNotEmpty) {
        _images.add(_EditableImage.existing(legacy.toString()));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= kMaxEditPostImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('post_max_images'.tr(namedArgs: {'max': '$kMaxEditPostImages'}))),
      );
      return;
    }
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;

      final remaining = kMaxEditPostImages - _images.length;
      final toAdd = picked.take(remaining).toList();

      for (final file in toAdd) {
        final bytes = await file.readAsBytes();
        _images.add(_EditableImage.fresh(bytes));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    }
  }

  Future<void> _pickSingleFromCamera() async {
    if (kIsWeb) return;
    if (_images.length >= kMaxEditPostImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('post_max_images'.tr(namedArgs: {'max': '$kMaxEditPostImages'}))),
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
      setState(() => _images.add(_EditableImage.fresh(bytes)));
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
      _images.removeAt(index);
      if (_currentPreviewIndex >= _images.length) {
        _currentPreviewIndex = _images.isEmpty ? 0 : _images.length - 1;
      }
    });
  }

  Future<void> _saveChanges() async {
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
      final List<String> imagesBase64 = _images.map((img) => img.toBase64()).toList();

      await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'images': imagesBase64,
        'imageBase64': imagesBase64.isNotEmpty ? imagesBase64.first : '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('update_successful'.tr()), backgroundColor: kPrimaryGreen),
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
      if (mounted) setState(() => _isLoading = false);
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
          'edit_post_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // ✂️ เอา actions: [...] ออกเรียบร้อยแล้ว
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      if (_images.isNotEmpty)
                        Text(
                          '${_images.length}/$kMaxEditPostImages',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_images.isNotEmpty) ...[
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
                                itemCount: _images.length,
                                onPageChanged: (i) => setState(() => _currentPreviewIndex = i),
                                itemBuilder: (context, i) =>
                                    Image.memory(_images[i].displayBytes, fit: BoxFit.cover),
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
                            if (_images.length > 1)
                              Positioned(
                                bottom: 10,
                                left: 0, right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_images.length, (i) {
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
                    SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (int i = 0; i < _images.length; i++)
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
                                  child: Image.memory(_images[i].displayBytes, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          if (_images.length < kMaxEditPostImages)
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
                          border: Border.all(color: kAccentGreen),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 42, color: kPrimaryGreen),
                            const SizedBox(height: 10),
                            Text('tap_to_select_image'.tr(),
                                style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('post_multi_image_hint'.tr(namedArgs: {'max': '$kMaxEditPostImages'}),
                                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          ],
                        ),
                      ),
                    ),

                  if (!kIsWeb && _images.isNotEmpty && _images.length < kMaxEditPostImages) ...[
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

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : Text(
                        'update'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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