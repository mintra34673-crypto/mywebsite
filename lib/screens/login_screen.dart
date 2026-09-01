// lib/screens/login_screen.dart - REAL FIREBASE + LANGUAGE SWITCHER + SEPARATE RESET PASSWORD PAGE
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppColors {
  static const Color primary = Color(0xFF2D8E6F);
  static const Color primaryLight = Color(0xFF52C77E);
  static const Color primaryDark = Color(0xFF1B5E48);
  static const Color accent = Color(0xFF7FD8B8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1A1A);
  static const Color grey = Color(0xFF6C757D);
  static const Color bgLight = Color(0xFFF1F8F5);
  static const Color error = Color(0xFFEF5350);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSignUpMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ✅ เปลี่ยนภาษา
  Future<void> _changeLanguage(String langCode) async {
    await context.setLocale(Locale(langCode));
    if (mounted) setState(() {});
  }

  // ✅ Dialog เลือกภาษา
  void _showLanguageDialog() {
    final currentLang = context.locale.languageCode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text('choose_language'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇹🇭", style: TextStyle(fontSize: 24)),
              title: Text('thai_language'.tr()),
              trailing: Radio<String>(
                value: 'th',
                groupValue: currentLang,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  if (val != null) _changeLanguage(val);
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                _changeLanguage('th');
              },
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
              title: Text('english_language'.tr()),
              trailing: Radio<String>(
                value: 'en',
                groupValue: currentLang,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  if (val != null) _changeLanguage(val);
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                _changeLanguage('en');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // ✅ rebuild เมื่อเปลี่ยนภาษา
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.eco, size: 50, color: AppColors.white),
              ),
              const SizedBox(height: 20),
              const Text('BinSort',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit')),
              const SizedBox(height: 8),
              Text('login_slogan'.tr(),
                  style: const TextStyle(
                      color: AppColors.accent, fontSize: 14, fontFamily: 'Kanit')),
            ],
          ),
        ),
        // ✅ ปุ่มเปลี่ยนภาษา มุมขวาบน
        Positioned(
          top: 44,
          right: 16,
          child: GestureDetector(
            onTap: _showLanguageDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    context.locale.languageCode == 'th' ? 'ไทย' : 'EN',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSignUpMode) ...[
          _label('login_name'.tr()),
          const SizedBox(height: 8),
          _textField(
              controller: _nameController,
              hint: 'login_name_hint'.tr(),
              icon: Icons.person),
          const SizedBox(height: 20),
          _label('login_phone'.tr()),
          const SizedBox(height: 8),
          _textField(
              controller: _phoneController,
              hint: 'login_phone_hint'.tr(),
              icon: Icons.phone_android,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
        ],
        _label('login_email'.tr()),
        const SizedBox(height: 8),
        _textField(
            controller: _emailController,
            hint: 'login_email_hint'.tr(),
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        _label('login_password'.tr()),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'login_password_hint'.tr(),
            filled: true,
            fillColor: AppColors.bgLight,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        // ✅ ช่องยืนยันรหัสผ่าน (แสดงเฉพาะตอนสมัครสมาชิก)
        if (_isSignUpMode) ...[
          const SizedBox(height: 20),
          _label('login_confirm_password'.tr()),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'login_confirm_password_hint'.tr(),
              filled: true,
              fillColor: AppColors.bgLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ✅ ปุ่ม Sign In / Sign Up
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
              : Text(
                  _isSignUpMode ? 'login_signup_btn'.tr() : 'login_signin_btn'.tr(),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                      color: AppColors.white)),
        ),

        // ✅ ย้ายปุ่ม "ลืมรหัสผ่าน?" มาไว้ใต้ปุ่ม Sign In (แสดงเฉพาะตอน Sign In)
        if (!_isSignUpMode) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                );
              },
              child: Text(
                'login_forgot_password'.tr(),
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSignUpMode ? 'login_have_account'.tr() : 'login_no_account'.tr(),
              style: const TextStyle(fontFamily: 'Kanit', color: AppColors.grey),
            ),
            GestureDetector(
              onTap: () => setState(() => _isSignUpMode = !_isSignUpMode),
              child: Text(
                _isSignUpMode ? 'login_signin_btn'.tr() : 'login_signup_btn'.tr(),
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Kanit',
          color: AppColors.primaryDark));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.bgLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
    );
  }

  void _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('login_fill_all'.tr(), false);
      return;
    }
    if (_isSignUpMode) {
      if (name.isEmpty) {
        _showSnackbar('login_fill_name'.tr(), false);
        return;
      }
      if (phone.isEmpty) {
        _showSnackbar('login_fill_phone'.tr(), false);
        return;
      }
      if (password != confirmPassword) {
        _showSnackbar('login_passwords_not_match'.tr(), false);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUpMode) {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name': name,
          'email': email,
          'points': 0,
          'phone': phone,
          'profileImage': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _showSnackbar('login_signup_success'.tr(), true);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        _showSnackbar('login_signin_success'.tr(), true);
      }

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'login_err_not_found'.tr();
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'login_err_wrong'.tr();
          break;
        case 'email-already-in-use':
          msg = 'login_err_email_used'.tr();
          break;
        case 'weak-password':
          msg = 'login_err_weak'.tr();
          break;
        case 'invalid-email':
          msg = 'login_err_invalid_email'.tr();
          break;
        default:
          msg = '${'login_err_generic'.tr()}: ${e.message}';
      }
      _showSnackbar(msg, false);
    } catch (e) {
      _showSnackbar('${'login_err_generic'.tr()}: $e', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Kanit')),
        backgroundColor: isSuccess ? AppColors.primary : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ==========================================
// ✅ หน้าจอสำหรับกรอกอีเมลเพื่อรีเซ็ตรหัสผ่าน (New Page)
// ==========================================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackbar('login_fill_email_reset'.tr(), false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackbar('login_reset_email_sent'.tr(), true);

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'login_err_not_found'.tr();
          break;
        case 'invalid-email':
          msg = 'login_err_invalid_email'.tr();
          break;
        default:
          msg = '${'login_err_generic'.tr()}: ${e.message}';
      }
      _showSnackbar(msg, false);
    } catch (e) {
      _showSnackbar('${'login_err_generic'.tr()}: $e', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Kanit')),
        backgroundColor: isSuccess ? AppColors.primary : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // ช่วยสั่ง rebuild เวลาสลับภาษา
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text(
                'login_forgot_password'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'login_forgot_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Kanit',
                  color: AppColors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'login_email_hint'.tr(),
                  filled: true,
                  fillColor: AppColors.bgLight,
                  prefixIcon: const Icon(Icons.email, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'login_send_reset_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                          color: AppColors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
