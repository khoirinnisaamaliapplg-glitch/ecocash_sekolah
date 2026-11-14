import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';

/// Ubah kata sandi akun — `PATCH /users/me/password`.
///
/// Backend memvalidasi `currentPassword` + `newPassword` (6–72 karakter, harus
/// berbeda dari yang lama) dan menolak permintaan berulang lewat rate limiter,
/// jadi layar ini hanya perlu memunculkan pesan server apa adanya.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color _accent = Color(0xFFE53935);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiClient.patch(
        ApiConfig.changePassword,
        body: <String, dynamic>{
          'currentPassword': _currentController.text,
          'newPassword': _newController.text,
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _humanMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Gagal mengubah kata sandi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pesan backend berbahasa Inggris; terjemahkan yang sudah dikenal dan
  /// biarkan sisanya tampil apa adanya supaya tidak ada info yang hilang.
  String _humanMessage(ApiException e) {
    final String message = e.message;

    if (message.contains('Incorrect current password')) {
      return 'Kata sandi saat ini salah.';
    }
    if (message.contains('must be different from current password')) {
      return 'Kata sandi baru harus berbeda dari kata sandi saat ini.';
    }
    if (message.contains('between 6 and 72')) {
      return 'Kata sandi harus 6–72 karakter.';
    }
    if (e.statusCode == 429) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    if (e.isUnauthorized) {
      return 'Sesi login berakhir. Silakan masuk kembali.';
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: _buildFormCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _accent,
        image: DecorationImage(
          image: AssetImage('assets/bgp.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 2),
              const Expanded(
                child: Text(
                  'Ubah Kata Sandi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keamanan Akun',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Gunakan kata sandi yang tidak dipakai di aplikasi lain.',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            _buildInputLabel('Kata Sandi Saat Ini'),

            const SizedBox(height: 8),

            TextFormField(
              controller: _currentController,
              enabled: !_isLoading,
              obscureText: _obscureCurrent,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              decoration: _inputDecoration(
                hint: 'Masukkan kata sandi saat ini',
                icon: Icons.lock_outline_rounded,
                obscure: _obscureCurrent,
                onToggleObscure: () => setState(
                  () => _obscureCurrent = !_obscureCurrent,
                ),
              ),
              validator: (String? value) {
                if ((value ?? '').isEmpty) {
                  return 'Kata sandi saat ini wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildInputLabel('Kata Sandi Baru'),

            const SizedBox(height: 8),

            TextFormField(
              controller: _newController,
              enabled: !_isLoading,
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _inputDecoration(
                hint: 'Minimal 6 karakter',
                icon: Icons.lock_reset_rounded,
                obscure: _obscureNew,
                onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              ),
              validator: (String? value) {
                final String password = value ?? '';

                if (password.isEmpty) return 'Kata sandi baru wajib diisi';
                if (password.length < 6) return 'Minimal 6 karakter';
                if (password.length > 72) return 'Maksimal 72 karakter';
                if (password == _currentController.text) {
                  return 'Harus berbeda dari kata sandi saat ini';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildInputLabel('Ulangi Kata Sandi Baru'),

            const SizedBox(height: 8),

            TextFormField(
              controller: _confirmController,
              enabled: !_isLoading,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                hint: 'Ketik ulang kata sandi baru',
                icon: Icons.check_circle_outline_rounded,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (String? value) {
                if ((value ?? '').isEmpty) {
                  return 'Ulangi kata sandi baru';
                }
                if (value != _newController.text) {
                  return 'Konfirmasi tidak sama dengan kata sandi baru';
                }
                return null;
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              _buildErrorBanner(_errorMessage!),
            ],

            const SizedBox(height: 28),

            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C6C1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB71C1C),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF424242),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF757575), size: 22),
      suffixIcon: IconButton(
        onPressed: onToggleObscure,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF9E9E9E),
          size: 21,
        ),
        tooltip: obscure ? 'Tampilkan' : 'Sembunyikan',
      ),
      filled: true,
      fillColor: const Color(0xFFF7F9FB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: const Color(0xFFEF9A9A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_reset_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Simpan Kata Sandi Baru',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
