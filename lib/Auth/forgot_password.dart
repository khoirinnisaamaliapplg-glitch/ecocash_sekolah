import 'dart:async';

import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Minta tautan reset kata sandi — `POST /auth/forgot-password`.
///
/// Endpoint-nya sengaja selalu menjawab pesan umum ("jika email terdaftar…"),
/// supaya tidak bisa dipakai menebak akun mana yang ada. Layar ini mengikuti
/// aturan itu: setelah server menjawab 2xx, tampilkan "periksa email", apa pun
/// isi alamat yang diketik.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const Color _accent = Color(0xFF2E7D32);
  static const Color _accentSoft = Color(0xFFE8F5E9);

  /// Jeda kirim ulang. Server memakai `authLimiter`, jadi tombol yang bisa
  /// ditekan berulang hanya akan berakhir dengan `429`.
  static const int _resendCooldownSeconds = 60;

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();

    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    final String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage('Email wajib diisi.', isError: true);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Format email tidak valid.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiClient.post(
        ApiConfig.forgotPassword,
        body: <String, dynamic>{'email': email},
        // Endpoint publik: jangan kirim token yang mungkin sudah kedaluwarsa.
        auth: false,
      );

      if (!mounted) return;

      setState(() => _emailSent = true);
      _startCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(_humanMessage(e), isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal mengirim tautan reset: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _cooldown -= 1);

      if (_cooldown <= 0) {
        timer.cancel();
        setState(() => _cooldown = 0);
      }
    });
  }

  String _humanMessage(ApiException e) {
    if (e.statusCode == 429) {
      return 'Terlalu banyak permintaan. Tunggu beberapa menit lalu coba lagi.';
    }
    if (e.message.contains('email')) {
      return 'Format email tidak valid.';
    }

    return e.message;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFE53935) : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _goToLogin() {
    // Halaman ini dibuka dari Login, jadi cukup kembali. `maybePop` menjaga
    // kalau suatu saat dibuka sebagai route pertama.
    Navigator.of(context).maybePop();
  }

  /// Reset kata sandi diselesaikan di halaman akun (web), bukan di aplikasi.
  Future<void> _openAccountSite() async {
    final Uri uri = Uri.parse(ApiConfig.accountUrl);

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          'Buka ${ApiConfig.accountUrl} di browser untuk melanjutkan.',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage(
        'Buka ${ApiConfig.accountUrl} di browser untuk melanjutkan.',
        isError: true,
      );
    }
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _emailSent ? _buildEmailSent() : _buildForgotForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'assets/logokids.jpeg',
            height: 110,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 32),

        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: _accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_outlined,
              size: 46,
              color: _accent,
            ),
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Lupa Kata Sandi?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D2939),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Masukkan email yang terdaftar pada akun EcoCash. '
          'Kami akan mengirimkan tautan untuk membuat kata sandi baru.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 30),

        const Text(
          'Email',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) {
            if (!_isLoading) _requestPasswordReset();
          },
          decoration: _inputDecoration(hint: 'nama@email.com'),
        ),

        const SizedBox(height: 26),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestPasswordReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: const Color(0xFFA5D6A7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                    'Kirim Tautan Reset',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _goToLogin,
            icon: const Icon(Icons.arrow_back, size: 18, color: _accent),
            label: const Text(
              'Kembali ke Login',
              style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSent() {
    final String email = _emailController.text.trim().toLowerCase();

    return Column(
      children: [
        const SizedBox(height: 12),

        Image.asset(
          'assets/logokids.jpeg',
          height: 110,
          fit: BoxFit.contain,
        ),

        const SizedBox(height: 36),

        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: _accentSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 52,
            color: _accent,
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Periksa Email Anda',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D2939),
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Jika email tersebut terdaftar di EcoCash, '
          'kami telah mengirimkan tautan reset kata sandi ke:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Tautan tersebut membuka halaman akun EcoCash di browser — '
          'kata sandi baru diatur di sana, bukan di aplikasi ini.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),

        const SizedBox(height: 10),

        SelectableText(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _accent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 24),

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
                  'Belum menemukan email? Periksa folder Spam, Junk, atau '
                  'Promotions. Tautan hanya berlaku untuk waktu terbatas.',
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

        const SizedBox(height: 26),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openAccountSite,
            icon: const Icon(Icons.open_in_new_rounded, size: 19),
            label: const Text(
              'Buka Halaman Akun',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: (_isLoading || _cooldown > 0)
                ? null
                : _requestPasswordReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  )
                : Text(
                    _cooldown > 0
                        ? 'Kirim ulang dalam ${_cooldown}s'
                        : 'Kirim Ulang Email',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _goToLogin,
            style: TextButton.styleFrom(foregroundColor: _accent),
            child: const Text(
              'Kembali ke Login',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.email_outlined),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }
}
