import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';

/// Edit profil sesuai kontrak backend:
///
/// - `PATCH /users/me` hanya menerima `name` dan `username`.
/// - Email punya endpoint sendiri, `PATCH /users/me/email`, dan hanya boleh
///   selama alamatnya belum terverifikasi (kalau sudah, server menjawab
///   `400 EMAIL_ALREADY_VERIFIED`).
///
/// Karena itu layar ini tidak lagi mengirim `email` ke `PATCH /users/me` -
/// dulu nilainya diabaikan server sehingga perubahan email tampak "berhasil"
/// padahal tidak tersimpan.
class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color _accent = Color(0xFFE53935);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  /// Dipakai dialog "Ubah email". Disimpan sebagai field supaya controller-nya
  /// baru di-dispose saat halaman ditutup, bukan saat animasi dialog berjalan.
  final TextEditingController _emailInputController = TextEditingController();

  late final String _initialName;
  late final String _initialUsername;
  late String _email;
  late bool _isVerified;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _initialName = (widget.user['name'] ?? '').toString().trim();
    _initialUsername = (widget.user['username'] ?? '').toString().trim();
    _email = (widget.user['email'] ?? '').toString().trim();
    _isVerified = widget.user['isVerified'] == true;

    _nameController.text = _initialName;
    _usernameController.text = _initialUsername;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailInputController.dispose();

    super.dispose();
  }

  String get _trimmedName => _nameController.text.trim();
  String get _trimmedUsername => _usernameController.text.trim();

  bool get _hasChanges =>
      _trimmedName != _initialName || _trimmedUsername != _initialUsername;

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? _accent : null,
        ),
      );
  }

  Future<void> _save() async {
    if (_isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_hasChanges) {
      _showMessage('Belum ada perubahan untuk disimpan.');
      return;
    }

    /*
     * Hanya field yang benar-benar berubah yang dikirim. `PATCH /users/me`
     * menolak request tanpa name/username ("Name or username is required").
     */
    final Map<String, dynamic> body = <String, dynamic>{
      if (_trimmedName != _initialName) 'name': _trimmedName,
      if (_trimmedUsername != _initialUsername) 'username': _trimmedUsername,
    };

    setState(() => _isLoading = true);

    try {
      final dynamic payload = await ApiClient.patch(
        ApiConfig.updateProfile,
        body: body,
      );

      if (!mounted) return;

      final Map<String, dynamic> result = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};

      if (result.isEmpty) {
        _showMessage('Respons server tidak dikenali.', error: true);
        return;
      }

      // Profil memakai hasil ini untuk memperbarui layar tanpa request ulang.
      Navigator.pop(context, result);
    } on ApiException catch (e) {
      _showMessage(_humanMessage(e), error: true);
    } catch (e) {
      _showMessage('Gagal menyimpan profil: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeEmail() async {
    _emailInputController.text = _email;
    final GlobalKey<FormState> emailFormKey = GlobalKey<FormState>();

    final String? value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah email'),
        content: Form(
          key: emailFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tautan verifikasi akan dikirim ke alamat baru. '
                'Alamat lama langsung tidak berlaku.',
                style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailInputController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email baru',
                  border: OutlineInputBorder(),
                ),
                validator: (String? input) {
                  final String email = (input ?? '').trim();

                  if (email.isEmpty) return 'Email wajib diisi';
                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email)) {
                    return 'Format email tidak valid';
                  }
                  if (email.toLowerCase() == _email.toLowerCase()) {
                    return 'Email sama dengan yang sekarang';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (emailFormKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, _emailInputController.text.trim());
              }
            },
            child: const Text('Kirim verifikasi'),
          ),
        ],
      ),
    );

    if (value == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final dynamic payload = await ApiClient.patch(
        ApiConfig.changeEmail,
        body: <String, dynamic>{'email': value},
      );

      if (!mounted) return;

      final Map<String, dynamic> result = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};

      setState(() {
        _email = (result['email'] ?? value).toString();
        _isVerified = result['isVerified'] == true;
      });

      _showMessage(
        'Email diperbarui. Cek kotak masuk untuk tautan verifikasi.',
      );
    } on ApiException catch (e) {
      _showMessage(_humanMessage(e), error: true);
    } catch (e) {
      _showMessage('Gagal mengubah email: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pesan server diterjemahkan ke bahasa layar; selain itu pakai pesan aslinya.
  String _humanMessage(ApiException e) {
    final String message = e.message;

    if (message.contains('Username already exists')) {
      return 'Username sudah dipakai. Pilih yang lain.';
    }
    if (message.contains('Email already registered')) {
      return 'Email sudah terdaftar di akun lain.';
    }
    if (message.contains('EMAIL_ALREADY_VERIFIED') ||
        message.contains('already verified')) {
      return 'Email sudah terverifikasi sehingga tidak bisa diubah di sini.';
    }
    if (e.statusCode == 429) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
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
                  'Edit Profil',
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
              'Informasi Pribadi',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Nama dan username dipakai di riwayat dan struk setoran.',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            _buildInputLabel('Nama Lengkap'),

            const SizedBox(height: 8),

            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'Masukkan nama lengkap',
                icon: Icons.person_outline_rounded,
              ),
              validator: (String? value) {
                final String name = (value ?? '').trim();

                if (name.isEmpty) return 'Nama wajib diisi';
                if (name.length < 2) return 'Nama minimal 2 karakter';
                if (name.length > 150) return 'Nama maksimal 150 karakter';

                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildInputLabel('Username'),

            const SizedBox(height: 8),

            TextFormField(
              controller: _usernameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                hint: 'huruf, angka, garis bawah',
                icon: Icons.alternate_email_rounded,
              ),
              onFieldSubmitted: (_) => _save(),
              validator: (String? value) {
                final String username = (value ?? '').trim();

                // Backend mengizinkannya kosong (field opsional), tetapi kalau
                // diisi harus 3-50 karakter dan hanya [a-zA-Z0-9_].
                if (username.isEmpty) return null;
                if (username.length < 3) return 'Username minimal 3 karakter';
                if (username.length > 50) return 'Username maksimal 50 karakter';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                  return 'Hanya huruf, angka, dan garis bawah';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildInputLabel('Email'),

            const SizedBox(height: 8),

            _buildEmailBox(),

            const SizedBox(height: 28),

            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                color: Color(0xFF757575),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _email.isEmpty ? 'Belum ada email' : _email,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildVerifiedChip(),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            _isVerified
                ? 'Email sudah terverifikasi dan tidak dapat diubah di sini.'
                : 'Email belum terverifikasi, jadi masih bisa diganti.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
          ),

          if (!_isVerified) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isLoading ? null : _changeEmail,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF3478F6),
                ),
                child: const Text('Ubah email'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifiedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _isVerified
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _isVerified ? 'Terverifikasi' : 'Belum',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _isVerified
              ? const Color(0xFF2E7D32)
              : const Color(0xFFEF6C00),
        ),
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
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF757575), size: 22),
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
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
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
