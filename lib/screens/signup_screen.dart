import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('please_fill_required_fields'.tr());
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('passwords_do_not_match'.tr());
      return;
    }

    if (_passwordController.text.length < 8) {
      _showMessage('password_min_chars'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. สร้าง User ใน Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. เก็บข้อมูลเพิ่มลงใน Firestore พร้อมตั้งค่า Points เริ่มต้นเป็น 0
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'profileImage': '', // เพิ่มไว้สำหรับเก็บ URL รูปโปรไฟล์ในอนาคต
            'points': 0, // <--- เพิ่มตรงนี้ ทุกคนสมัครใหม่จะได้ 0 แต้มทันที
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        _showMessage('successfully_registered'.tr());
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'error_occurred'.tr(args: ['']));
    } catch (e) {
      _showMessage('error_occurred'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'sign_up'.tr(),
          style: const TextStyle(
            color: Color(0xFFD48EA1),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildTextField(
                  _fullNameController,
                  Icons.people_outline,
                  'full_name'.tr(),
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _phoneController,
                  Icons.phone_android,
                  'phone_number'.tr(),
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _emailController,
                  Icons.email_outlined,
                  'email'.tr(),
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _passwordController,
                  Icons.lock_outline,
                  'password'.tr(),
                  isObscure: true,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, top: 5),
                    child: Text(
                      'password_requirements'.tr(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  _confirmPasswordController,
                  Icons.lock_outline,
                  'confirm_password'.tr(),
                  isObscure: true,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B996),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'sign_up'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isObscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        fillColor: const Color(0xFFF1EDE4),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
