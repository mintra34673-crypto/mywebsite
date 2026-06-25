import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ranking'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // ลบ orderBy ออก เรียงใน client-side แทน
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('no_user_data_found'.tr()));
                }

                // เรียงจากมากไปน้อยใน client-side
                var docs = List.of(snapshot.data!.docs)
                  ..sort((a, b) {
                    final pa = (a.data() as Map)['points'] as int? ?? 0;
                    final pb = (b.data() as Map)['points'] as int? ?? 0;
                    return pb.compareTo(pa);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = docs[index].id == currentUser?.uid;
                    int rank = index + 1;

                    return _buildRankingTile(
                      rank: rank,
                      name: data['name'] ?? 'unknown'.tr(),
                      points: data['points'] ?? 0,
                      imageUrl: data['profileImage'],
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _buildMyRankFooter(currentUser?.uid),
        ],
      ),
    );
  }

  Widget _buildRankingTile({
    required int rank,
    required String name,
    required int points,
    String? imageUrl,
    required bool isMe,
  }) {
    Color bgColor = Colors.white;
    if (rank == 1)
      bgColor = const Color(0xFFFFCDD2);
    else if (rank <= 3)
      bgColor = const Color(0xFFFCE4EC);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (rank == 1)
                  const Icon(Icons.workspace_premium,
                      size: 18, color: Colors.black),
                Text(
                  "$rank",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: rank == 1 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 25,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            points.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankFooter(String? myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        var docs = List.of(snapshot.data!.docs)
          ..sort((a, b) {
            final pa = (a.data() as Map)['points'] as int? ?? 0;
            final pb = (b.data() as Map)['points'] as int? ?? 0;
            return pb.compareTo(pa);
          });

        int myIndex = docs.indexWhere((doc) => doc.id == myUid);
        if (myIndex == -1) return const SizedBox();

        var myData = docs[myIndex].data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Row(
            children: [
              Text(
                'you'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 20),
              CircleAvatar(
                radius: 25,
                backgroundImage: myData['profileImage'] != null
                    ? NetworkImage(myData['profileImage'])
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  myData['name'] ?? "",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Text(
                myData['points'].toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
