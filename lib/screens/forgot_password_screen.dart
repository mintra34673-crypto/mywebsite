import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  Future<void> _sendPasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('please_enter_email'.tr())));
      return;
    }

    try {
      // ส่งลิงก์รีเซ็ตรหัสผ่านเข้าอีเมลโดยตรง
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        // แสดงข้อความบอกผู้ใช้
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('email_sent_reset_link'.tr()),
            duration: const Duration(seconds: 5),
          ),
        );
        // เด้งกลับไปหน้า Login ทันที
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'error_occurred'.tr(args: [e.message ?? '']);
      if (e.code == 'user-not-found') {
        message = 'user_not_found'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'invalid_email'.tr();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_occurred'.tr(args: [e.toString()]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.grey),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Text(
              'forgot_password'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD48EA1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'forgot_password_description'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'enter_your_email'.tr(),
                prefixIcon: const Icon(Icons.email_outlined),
                fillColor: const Color(0xFFF1EDE4),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _sendPasswordReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4B996),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'verify_email'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
