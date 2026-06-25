import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('please_fill_required_fields'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _userController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'error_occurred'.tr(args: [e.message ?? '']);
      if (e.code == 'user-not-found')
        message = 'user_not_found'.tr();
      else if (e.code == 'wrong-password')
        message = 'wrong_password'.tr();
      else if (e.code == 'invalid-email')
        message = 'invalid_email'.tr();

      _showSnackBar(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 80, 30, 30), // ✅ เพิ่ม top
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ โลโก้อยู่กลางๆ หัว
                Image.asset(
                  'assets/icon/icon.png',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 40),

                // ช่อง Email
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
                    ),
                    hintText: 'email'.tr(),
                    fillColor: const Color(0xFFF1EDE4),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // ช่อง Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                    ),
                    hintText: 'password'.tr(),
                    fillColor: const Color(0xFFF1EDE4),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ปุ่ม Login
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B996),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'login'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),

                // ปุ่ม Sign up
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: Color(0xFFD48EA1),
                    ),
                    label: Text(
                      'sign_up'.tr(),
                      style: const TextStyle(
                        color: Color(0xFFD48EA1),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ลืมรหัสผ่าน
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'forgot_your_password'.tr(),
                      style: const TextStyle(color: Colors.black45),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'click_here'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFD48EA1),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
