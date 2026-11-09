import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:ecocash_sekolah/ipconfig.dart';

class EmailVerificationPage extends StatefulWidget {
  final String token;

  const EmailVerificationPage({super.key, required this.token});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;
  bool _success = false;

  String _message = 'Memverifikasi email Anda...';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _verifyEmail();
  }

  // ============================================================
  // VERIFY EMAIL
  // ============================================================

  Future<void> _verifyEmail() async {
    final String token = widget.token.trim();

    debugPrint('');
    debugPrint('======================================');
    debugPrint('EMAIL VERIFICATION PAGE');
    debugPrint('TOKEN AVAILABLE : ${token.isNotEmpty}');
    debugPrint('URL             : ${ApiConfig.confirmEmailVerification}');
    debugPrint('======================================');
    debugPrint('');

    // ==========================================================
    // TOKEN EMPTY
    // ==========================================================

    if (token.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _success = false;
        _message = 'Token verifikasi tidak ditemukan pada link email.';
      });

      return;
    }

    try {
      // ========================================================
      // REQUEST
      // ========================================================

      final response = await http.post(
        Uri.parse(ApiConfig.confirmEmailVerification),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );

      debugPrint('');
      debugPrint('========== VERIFY EMAIL ==========');
      debugPrint('STATUS : ${response.statusCode}');
      debugPrint('BODY   : ${response.body}');
      debugPrint('==================================');
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

      final String serverMessage =
          responseData is Map && responseData['message'] != null
          ? responseData['message'].toString().trim()
          : '';

      if (!mounted) return;

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _loading = false;
          _success = true;

          _message = serverMessage.isNotEmpty
              ? serverMessage
              : 'Email berhasil diverifikasi.';
        });

        return;
      }

      // ========================================================
      // ALREADY VERIFIED
      // ========================================================

      final String lowerMessage = serverMessage.toLowerCase();

      if (lowerMessage.contains('already verified') ||
          lowerMessage.contains('sudah diverifikasi')) {
        setState(() {
          _loading = false;
          _success = true;
          _message = 'Email Anda sudah terverifikasi.';
        });

        return;
      }

      // ========================================================
      // FAILED
      // ========================================================

      setState(() {
        _loading = false;
        _success = false;

        _message = serverMessage.isNotEmpty
            ? serverMessage
            : 'Token verifikasi tidak valid '
                  'atau sudah kedaluwarsa.';
      });
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('VERIFY EMAIL ERROR');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _success = false;
        _message = 'Tidak dapat terhubung ke server EcoCash.';
      });
    }
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> _retryVerification() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _success = false;
      _message = 'Memverifikasi email Anda...';
    });

    await _verifyEmail();
  }

  // ============================================================
  // LOGIN
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

      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),

                  // =================================================
                  // LOGO
                  // =================================================
                  Image.asset(
                    'assets/logo.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 55),

                  // =================================================
                  // LOADING
                  // =================================================
                  if (_loading) ...[
                    Container(
                      width: 100,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Memverifikasi Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D2939),
                      ),
                    ),
                  ],

                  // =================================================
                  // RESULT
                  // =================================================
                  if (!_loading) ...[
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _success
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 60,
                        color: _success ? const Color(0xFF2E7D32) : Colors.red,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      _success ? 'Email Verified!' : 'Verifikasi Gagal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D2939),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // =================================================
                  // MESSAGE
                  // =================================================
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 45),

                  // =================================================
                  // SUCCESS BUTTON
                  // =================================================
                  if (!_loading && _success)
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
                          'Login Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // =================================================
                  // FAILED BUTTON
                  // =================================================
                  if (!_loading && !_success) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _retryVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Coba Verifikasi Lagi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _goToLogin,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Kembali ke Login',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
