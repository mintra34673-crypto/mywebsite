import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart'; // ✅ แก้ error: ลืม import ตัวนี้ ทำให้ DateFormat ใช้ไม่ได้และหน้าจอแดง
import 'dart:convert';
import 'edit_post_screen.dart';
import 'app_theme.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.post,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCommenting = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await _firestore
          .collection('community_posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(currentUser.uid)
          .get();

      if (mounted) {
        setState(() => _isLiked = doc.exists);
      }
    } catch (e) {
      debugPrint('Error checking like: $e');
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('must_login'.tr())),
      );
      return;
    }

    try {
      final likeRef = _firestore
          .collection('community_posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(currentUser.uid);

      if (_isLiked) {
        await likeRef.delete();
        await _firestore.collection('community_posts').doc(widget.postId).update({
          'likes': FieldValue.increment(-1),
        });
        setState(() => _isLiked = false);
      } else {
        await likeRef.set({'likedAt': Timestamp.now()});
        await _firestore.collection('community_posts').doc(widget.postId).update({
          'likes': FieldValue.increment(1),
        });
        setState(() => _isLiked = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'bin_error'.tr()}: $e')),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('comment_cannot_empty'.tr())),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('must_login'.tr())),
      );
      return;
    }

    setState(() => _isCommenting = true);

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['name'] ?? 'unknown'.tr();

      await _firestore
          .collection('community_posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': currentUser.uid,
        'userName': userName,
        'createdAt': Timestamp.now(),
      });

      await _firestore.collection('community_posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('comment_posted'.tr()), backgroundColor: kPrimaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCommenting = false);
      }
    }
  }

  // ✅ ลบโพสต์
  Future<void> _deletePost() async {
    try {
      await _firestore.collection('community_posts').doc(widget.postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('post_deleted'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'bin_error'.tr()}: $e')),
        );
      }
    }
  }

  // ✅ ดึงรูปทั้งหมดของโพสต์ รองรับทั้งแบบใหม่ (images list) และเก่า (imageBase64 เดี่ยว)
  List<String> _getPostImages() {
    final rawImages = widget.post['images'];
    if (rawImages is List) {
      final list = rawImages.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }
    final legacy = widget.post['imageBase64'];
    if (legacy != null && legacy.toString().isNotEmpty) {
      return [legacy.toString()];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isOwner = currentUser?.uid == widget.post['userId'];
    final images = _getPostImages();

    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'post_detail'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // ✅ Edit/Delete Menu in AppBar
        actions: [
          if (isOwner)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20, color: kDarkGreen),
                      const SizedBox(width: 8),
                      Text('edit'.tr()),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPostScreen(
                          postId: widget.postId,
                          post: widget.post,
                        ),
                      ),
                    );
                  },
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('confirm_delete'.tr()),
                        content: Text('delete_post_confirm'.tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('cancel'.tr()),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deletePost();
                            },
                            child: Text('delete'.tr(),
                                style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Post header card
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
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: kAccentGreen.withOpacity(0.3),
                              backgroundImage: (widget.post['userProfileImage'] !=
                                      null &&
                                  widget.post['userProfileImage'].isNotEmpty)
                                  ? NetworkImage(widget.post['userProfileImage'])
                                  : null,
                              child: (widget.post['userProfileImage'] == null ||
                                      widget.post['userProfileImage'].isEmpty)
                                  ? Text(
                                      (widget.post['userName'] as String?)
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          '?',
                                      style: const TextStyle(
                                        color: kDarkGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.post['userName'] ?? 'unknown'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(widget.post['createdAt']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.post['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.post['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ Post images (รองรับหลายรูป แบบเลื่อนดูได้)
                  if (images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _DetailImageCarousel(images: images),
                    ),
                  if (images.isNotEmpty) const SizedBox(height: 16),

                  // ✅ Interaction stats
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${widget.post['likes'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                            Text(
                              'likes'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${widget.post['commentCount'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryGreen,
                              ),
                            ),
                            Text(
                              'comments'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ✅ Comments section
                  Text(
                    'comments'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('community_posts')
                        .doc(widget.postId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryGreen,
                          ),
                        );
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'no_comments_yet'.tr(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final comment = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: kAccentGreen.withOpacity(0.3),
                                      child: Text(
                                        (comment['userName'] as String?)
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            '?',
                                        style: const TextStyle(
                                          color: kDarkGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment['userName'] ?? 'unknown'.tr(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(
                                                comment['createdAt']),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['text'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ✅ Like and comment input section
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isLiked
                            ? Colors.red.withOpacity(0.08)
                            : kAccentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.redAccent : kDarkGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isLiked ? 'liked'.tr() : 'like'.tr(),
                            style: TextStyle(
                              color: _isLiked ? Colors.redAccent : kDarkGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Comment input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          enabled: !_isCommenting,
                          maxLines: null,
                          cursorColor: kPrimaryGreen,
                          decoration: InputDecoration(
                            hintText: 'type_comment'.tr(),
                            filled: true,
                            fillColor: kScreenBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isCommenting ? null : _addComment,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: kPrimaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: _isCommenting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'just_now'.tr();
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} ${'minutes_ago'.tr()}';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} ${'hours_ago'.tr()}';
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }
}

// ✅ แกลเลอรีรูปภาพในหน้ารายละเอียดโพสต์ เลื่อนดูได้ทีละรูป พร้อมจุดบอกตำแหน่ง
class _DetailImageCarousel extends StatefulWidget {
  final List<String> images;
  const _DetailImageCarousel({required this.images});

  @override
  State<_DetailImageCarousel> createState() => _DetailImageCarouselState();
}

class _DetailImageCarouselState extends State<_DetailImageCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.1,
          child: ScrollConfiguration(
            behavior: MouseDragScrollBehavior(),
            child: PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return Container(
                color: Colors.grey[200],
                child: Image.memory(
                  base64Decode(widget.images[i]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              );
            },
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_index + 1}/${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                final active = i == _index;
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
      ],
    );
  }
}