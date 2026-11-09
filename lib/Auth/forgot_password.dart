import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:ecocash_sekolah/ipconfig.dart';
// import 'package:ecocash_indonesia/Auth/login.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _emailController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool _emailSent = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();

    super.dispose();
  }

  // ============================================================
  // REQUEST FORGOT PASSWORD
  // ============================================================

  Future<void> _requestPasswordReset() async {
    final String email = _emailController.text.trim().toLowerCase();

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (email.isEmpty) {
      _showMessage('Email wajib diisi.', Colors.orange);

      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Format email tidak valid.', Colors.orange);

      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('');
      debugPrint('======================================');
      debugPrint('FORGOT PASSWORD ECOCASH');
      debugPrint('URL   : ${ApiConfig.forgotPassword}');
      debugPrint('EMAIL : $email');
      debugPrint('======================================');

      // ========================================================
      // REQUEST
      // ========================================================

      final response = await http.post(
        Uri.parse(ApiConfig.forgotPassword),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      debugPrint('');
      debugPrint('========== FORGOT PASSWORD ==========');
      debugPrint('STATUS : ${response.statusCode}');
      debugPrint('BODY   : ${response.body}');
      debugPrint('=====================================');
      debugPrint('');

      // ========================================================
      // PARSE RESPONSE
      // ========================================================

      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        responseData = null;
      }

      if (!mounted) return;

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _emailSent = true;
        });

        return;
      }

      // ========================================================
      // ERROR
      // ========================================================

      String message = 'Gagal mengirim link reset password.';

      if (responseData is Map) {
        final dynamic serverMessage = responseData['message'];

        if (serverMessage != null &&
            serverMessage.toString().trim().isNotEmpty) {
          message = serverMessage.toString();
        }
      }

      _showMessage(message, Colors.red);
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('FORGOT PASSWORD ERROR: $e');
      debugPrint('$stackTrace');
      debugPrint('');

      if (!mounted) return;

      _showMessage('Tidak dapat terhubung ke server EcoCash.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  void _goToLogin() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1D2939),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),

                child: !_emailSent ? _buildForgotForm() : _buildEmailSent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORGOT PASSWORD FORM
  // ============================================================

  Widget _buildForgotForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ======================================================
        // LOGO
        // ======================================================
        Center(
          child: Image.asset(
            'assets/logo.png',
            height: 120,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 40),

        // ======================================================
        // ICON
        // ======================================================
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_outlined,
              size: 48,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // ======================================================
        // TITLE
        // ======================================================
        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D2939),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Masukkan email yang terdaftar pada akun EcoCash. '
          'Kami akan mengirimkan link untuk membuat password baru.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 32),

        // ======================================================
        // EMAIL LABEL
        // ======================================================
        const Text(
          'Email',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),

        const SizedBox(height: 8),

        // ======================================================
        // EMAIL INPUT
        // ======================================================
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,

          onSubmitted: (_) {
            if (!_isLoading) {
              _requestPasswordReset();
            }
          },

          decoration: InputDecoration(
            hintText: 'nama@email.com',

            prefixIcon: const Icon(Icons.email_outlined),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2E7D32),
                width: 1.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ======================================================
        // SEND BUTTON
        // ======================================================
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestPasswordReset,

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kirim Link Reset Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 18),

        // ======================================================
        // LOGIN
        // ======================================================
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _goToLogin,
            icon: const Icon(
              Icons.arrow_back,
              size: 18,
              color: Color(0xFF2E7D32),
            ),
            label: const Text(
              'Kembali ke Login',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMAIL SENT UI
  // ============================================================

  Widget _buildEmailSent() {
    final String email = _emailController.text.trim().toLowerCase();

    return Column(
      children: [
        const SizedBox(height: 20),

        // ======================================================
        // LOGO
        // ======================================================
        Image.asset('assets/logo.png', height: 120, fit: BoxFit.contain),

        const SizedBox(height: 50),

        // ======================================================
        // EMAIL ICON
        // ======================================================
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 55,
            color: Color(0xFF2E7D32),
          ),
        ),

        const SizedBox(height: 30),

        // ======================================================
        // TITLE
        // ======================================================
        const Text(
          'Periksa Email Anda',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D2939),
          ),
        ),

        const SizedBox(height: 14),

        // ======================================================
        // MESSAGE
        // ======================================================
        const Text(
          'Jika email tersebut terdaftar di EcoCash, '
          'kami telah mengirimkan link reset password ke:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF667085), fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 10),

        SelectableText(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 25),

        // ======================================================
        // INFO
        // ======================================================
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAECF0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: Color(0xFF667085)),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Belum menemukan email? '
                  'Periksa folder Spam, Junk, atau Promotions.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 35),

        // ======================================================
        // RESEND
        // ======================================================
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _requestPasswordReset,

            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2E7D32)),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2E7D32),
                    ),
                  )
                : const Text(
                    'Kirim Ulang Email',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // ======================================================
        // LOGIN
        // ======================================================
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goToLogin,

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: const Text(
              'Kembali ke Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}
