import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'edit_information_screen.dart'; // หน้าแก้ไขข้อมูล
import 'login_screen.dart'; // หน้า Login สำหรับ Logout

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // --- แก้ไขวงเล็บและจัดระเบียบฟังก์ชันเลือกภาษาให้ถูกต้อง ---
  Future<void> _showLanguageDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            'choose_language'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇹🇭", style: TextStyle(fontSize: 24)),
              title: Text('thai_language'.tr()),
              trailing: Radio<Locale>(
                value: const Locale('th'),
                groupValue: context.locale,
                onChanged: (val) async {
                  if (val != null) {
                    await context.setLocale(val);
                    if (mounted) setState(() {});
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              onTap: () async {
                await context.setLocale(const Locale('th'));
                if (mounted) setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
              title: Text('english_language'.tr()),
              trailing: Radio<Locale>(
                value: const Locale('en'),
                groupValue: context.locale,
                onChanged: (val) async {
                  if (val != null) {
                    await context.setLocale(val);
                    if (mounted) setState(() {});
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              onTap: () async {
                await context.setLocale(const Locale('en'));
                if (mounted) setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'profile'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('no_user_data_found'.tr()));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['name'] ?? 'unknown'.tr();
          int points = data['points'] ?? 0;
          String phone = data['phone'] ?? "-";
          String? profileImage = data['profileImage'];

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildUserCard(name, points, profileImage),
                const SizedBox(height: 30),
                _sectionTitle('personal_info'.tr()),
                _infoTile(Icons.phone, phone, Colors.green),
                _infoTile(Icons.email, user?.email ?? "-", Colors.grey),
                const SizedBox(height: 30),
                _sectionTitle('settings'.tr()),
                _settingsTile(Icons.person, 'edit_information'.tr(), () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditInformationScreen(),
                    ),
                  );
                }),
                _settingsTile(
                  Icons.language,
                  'change_language'.tr(),
                  _showLanguageDialog,
                ),
                const SizedBox(height: 50),
                _logoutButton(context),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(String name, int points, String? imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFEEEEEE),
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person, size: 40, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  Text(
                    " $points ${'points'.tr()}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 25, bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _infoTile(IconData icon, String text, Color color) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 15),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _settingsTile(IconData icon, String text, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: Colors.black),
          title: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      );

  Widget _logoutButton(BuildContext context) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFF8A80),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
    ),
    onPressed: () async {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.logout, color: Colors.black),
        const SizedBox(width: 10),
        Text(
          'logout'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
