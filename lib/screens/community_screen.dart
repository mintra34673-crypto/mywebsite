import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'edit_post_screen.dart';
import 'custom_bottom_nav.dart';
import 'app_theme.dart';
import 'countryside_painter.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ ลบโพสต์
  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('community_posts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('post_deleted'.tr())),
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

  @override
  Widget build(BuildContext context) {
    context.locale;
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'community'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: Opacity(
              opacity: 0.35,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: CountrysideScenePainter(),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('community_posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimaryGreen),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 80, color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'no_posts_yet'.tr(),
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final post =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final postId = snapshot.data!.docs[index].id;
                  final isOwner = currentUser?.uid == post['userId'];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            postId: postId,
                            post: post,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ User info header + Menu
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: kAccentGreen.withOpacity(0.3),
                                  backgroundImage: (post['userProfileImage'] != null &&
                                          post['userProfileImage'].isNotEmpty)
                                      ? NetworkImage(post['userProfileImage'])
                                      : null,
                                  child: (post['userProfileImage'] == null ||
                                          post['userProfileImage'].isEmpty)
                                      ? Text(
                                          (post['userName'] as String?)
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              '?',
                                          style: const TextStyle(
                                            color: kDarkGreen,
                                            fontWeight: FontWeight.bold,
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
                                        post['userName'] ?? 'unknown'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(post['createdAt']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ✅ Edit/Delete Menu
                                if (isOwner)
                                  PopupMenuButton(
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
                                                postId: postId,
                                                post: post,
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
                                                    _deletePost(postId);
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
                          ),
                          Divider(
                            color: Colors.grey.withOpacity(0.2),
                            thickness: 1,
                            height: 0,
                          ),
                          // ✅ Post content
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post['description'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ✅ Image preview (รองรับหลายรูปแบบใหม่ + โพสต์เก่าแบบรูปเดียว)
                          _buildPostImages(post),
                          // ✅ Interaction buttons
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInteractionButton(
                                  icon: Icons.favorite_border_rounded,
                                  label: '${post['likes'] ?? 0}',
                                  color: Colors.redAccent,
                                ),
                                _buildInteractionButton(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: '${post['commentCount'] ?? 0}',
                                  color: kLightGreen,
                                ),
                                _buildInteractionButton(
                                  icon: Icons.visibility_outlined,
                                  label: '${'view'.tr()} >',
                                  color: kDarkGreen,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: buildCustomBottomNav(context, 'community'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryGreen,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          ).then((_) {
            setState(() {});
          });
        },
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  // ✅ แสดงรูปภาพของโพสต์: รองรับทั้งโพสต์ใหม่ (หลายรูป, field 'images') และโพสต์เก่า (รูปเดียว, field 'imageBase64')
  Widget _buildPostImages(Map<String, dynamic> post) {
    final rawImages = post['images'];
    final List<String> images = (rawImages is List)
        ? rawImages.whereType<String>().where((s) => s.isNotEmpty).toList()
        : <String>[];

    if (images.isEmpty) {
      // fallback: โพสต์เก่าแบบรูปเดียว
      final legacy = post['imageBase64'];
      if (legacy != null && legacy.toString().isNotEmpty) {
        images.add(legacy.toString());
      }
    }

    if (images.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(15),
        bottomRight: Radius.circular(15),
      ),
      child: _PostImageCarousel(images: images),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
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
      if (difference.inDays < 7) {
        return '${difference.inDays} ${'days_ago'.tr()}';
      }
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return '';
    }
  }
}

// ✅ แกลเลอรีรูปภาพในโพสต์ แบบเลื่อนดูได้ทีละรูป (สไตล์ IG/FB) พร้อมจุดบอกตำแหน่ง
class _PostImageCarousel extends StatefulWidget {
  final List<String> images;
  const _PostImageCarousel({required this.images});

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
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