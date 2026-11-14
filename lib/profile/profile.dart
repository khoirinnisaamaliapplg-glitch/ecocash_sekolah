import 'package:ecocash_sekolah/Auth/login.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/notifikasi/notifikasi.dart';
import 'package:ecocash_sekolah/profile/changepassword.dart';
import 'package:ecocash_sekolah/profile/editprofile.dart';
import 'package:ecocash_sekolah/profile/organisasi.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Profil akun: identitas, aksi akun (edit profil / ubah kata sandi), dan keluar.
///
/// Datanya selalu diambil ulang dari `GET /users/me`, bukan dari payload login
/// yang tersimpan di memori, sehingga perubahan dari Edit Profil dan status
/// verifikasi email langsung terlihat di layar ini.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _accent = Color(0xFFE53935);

  Map<String, dynamic>? _user;
  String? _error;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  /// Notifikasi yang belum dibaca (`unreadCount` dari `GET /notifications`).
  int _unreadNotifications = 0;

  /// Sekolah pengguna + admin yang bisa dihubungi
  /// (`GET /users/me/organization`).
  Map<String, dynamic>? _organization;
  Map<String, dynamic>? _schoolAdmin;

  /// Sedang mengunggah / menghapus foto profil.
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// `GET /users/me` → `{ id, name, username, email, phoneNumber, role,
  /// createdAt, isVerified, emailVerifiedAt }`.
  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Profil dan jumlah notifikasi diambil bersamaan; badge tidak boleh
      // menggagalkan seluruh layar (kegagalannya sudah ditelan di helper).
      final List<dynamic> results = await Future.wait<dynamic>([
        ApiClient.getMap(ApiConfig.getUserProfile),
        _fetchUnreadNotifications(),
        _fetchMyOrganization(),
      ]);

      final Map<String, dynamic> user = results[0] as Map<String, dynamic>;

      final Map<String, dynamic> school =
          results[2] as Map<String, dynamic>? ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _user = user;
        _unreadNotifications = results[1] as int;
        _organization = _asMapOrNull(school['organization']);
        _schoolAdmin = _asMapOrNull(school['admin']);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      // 401 sudah ditangani ApiClient (token dibersihkan + pindah ke login).
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat profil: $e';
        _isLoading = false;
      });
    }
  }

  /// `GET /users/me/organization` → `{ organization, admin }`.
  ///
  /// Kegagalannya ditelan: bagian kontak sekolah hanya pelengkap, profil tetap
  /// harus terbuka.
  Future<Map<String, dynamic>> _fetchMyOrganization() async {
    try {
      return await ApiClient.getMap(ApiConfig.myOrganization);
    } catch (error) {
      debugPrint('PROFILE organization: $error');
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic>? _asMapOrNull(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// Jumlah notifikasi yang belum dibaca; 0 bila endpoint gagal.
  Future<int> _fetchUnreadNotifications() async {
    try {
      final Map<String, dynamic> data = await ApiClient.getMap(
        '${ApiConfig.notifications}?page=1&limit=1',
      );

      final dynamic count = data['unreadCount'];

      return count is num ? count.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotifikasiPage()),
    );

    if (!mounted) return;

    final int count = await _fetchUnreadNotifications();

    if (mounted) setState(() => _unreadNotifications = count);
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditProfile() async {
    final Map<String, dynamic>? updated =
        await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfilePage(user: _user ?? const {}),
          ),
        );

    if (!mounted || updated == null) return;

    /*
     * `PATCH /users/me` hanya mengembalikan { id, name, username, email }, jadi
     * hasilnya digabung dengan data sekarang supaya phoneNumber / isVerified
     * tidak hilang dari layar.
     */
    setState(() {
      _user = <String, dynamic>{...?_user, ...updated};
    });

    _showSnack('Profil berhasil diperbarui.');

    // Ambil ulang agar status verifikasi email (dan field lain) tetap akurat.
    await _load();
  }

  Future<void> _openChangePassword() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );

    if (!mounted || changed != true) return;

    _showSnack('Kata sandi berhasil diubah.');
  }

  Future<void> _handleLogout() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Keluar dari akun?'),
            content: const Text(
              'Anda perlu masuk kembali untuk melihat saldo dan menyetor sampah.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: _accent),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _isLoggingOut = true);

    /*
     * `POST /auth/logout` memasukkan token ke denylist server. Kalau panggilan
     * ini gagal (mis. jaringan putus atau token sudah kedaluwarsa) sesi lokal
     * tetap harus berakhir, jadi kegagalannya sengaja diabaikan.
     */
    try {
      await ApiClient.post(ApiConfig.logout);
    } catch (_) {
      /* best effort */
    }

    ApiConfig.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Transform.translate(
                offset: const Offset(0, -70),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 2),
                const Text(
                  'Profil Saya',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    final Map<String, dynamic>? user = _user;

    if (_isLoading && user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    if (user == null) {
      return Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Gagal memuat profil.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      );
    }

    final bool verified = user['isVerified'] == true;

    return Column(
      children: [
        _buildProfileIdentity(user, verified),

        const SizedBox(height: 22),

        _buildInfoRow('Username', user['username']),
        _buildInfoRow('No. Handphone', user['phoneNumber']),
        _buildInfoRow('Bergabung', _formatDate(user['createdAt'])),

        const SizedBox(height: 14),

        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

        const SizedBox(height: 16),

        // Satu baris saja; detail sekolah + admin ada di halamannya sendiri.
        _buildMenuTile(
          icon: Icons.school_outlined,
          title: 'Sekolah / Organisasi',
          subtitle: _schoolTileSubtitle(),
          onTap: _openOrganization,
        ),

        _buildMenuTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifikasi',
          subtitle: _unreadNotifications > 0
              ? '$_unreadNotifications belum dibaca'
              : 'Pemberitahuan, promo, dan info setoran',
          onTap: _openNotifications,
          trailing: _unreadNotifications > 0 ? _buildUnreadBadge() : null,
        ),

        _buildMenuTile(
          icon: Icons.person_outline_rounded,
          title: 'Edit Profil',
          subtitle: 'Nama dan username',
          onTap: _openEditProfile,
        ),

        _buildMenuTile(
          icon: Icons.lock_outline_rounded,
          title: 'Ubah Kata Sandi',
          subtitle: 'Kata sandi akun Anda',
          onTap: _openChangePassword,
        ),

        const SizedBox(height: 20),

        _buildLogoutButton(),
      ],
    );
  }

  /// Subjudul baris "Sekolah / Organisasi" di menu profil: nama sekolah saja.
  ///
  /// Nama admin sengaja tidak ditampilkan di sini — detailnya ada di halaman
  /// sekolah.
  String _schoolTileSubtitle() {
    final String name =
        (_organization?['name'] ?? ApiConfig.currentOrganization?['name'] ?? '')
            .toString()
            .trim();

    return name.isEmpty ? 'Lihat detail sekolah & admin' : name;
  }

  /// Buka detail sekolah (alamat, kode, admin + tombol kontak).
  Future<void> _openOrganization() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganisasiPage(
          organization: _organization,
          admin: _schoolAdmin,
        ),
      ),
    );

    if (!mounted) return;

    // Admin/kontak bisa saja diubah dari panel; segarkan diam-diam.
    final Map<String, dynamic> school = await _fetchMyOrganization();

    if (!mounted || school.isEmpty) return;

    setState(() {
      _organization = _asMapOrNull(school['organization']);
      _schoolAdmin = _asMapOrNull(school['admin']);
    });
  }

  Widget _buildProfileIdentity(Map<String, dynamic> user, bool verified) {
    final String name = (user['name'] ?? '').toString().trim();
    final String email = (user['email'] ?? '').toString().trim();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _showAvatarOptions,
            child: Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _buildAvatarImage(user, name),
                  ),
                ),
                if (_isUploadingAvatar)
                  const Positioned.fill(
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.black38,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3478F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          name.isEmpty ? 'Pengguna EcoCash' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          email.isEmpty ? 'Email belum diisi' : email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF757575),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: verified
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            verified ? 'Email terverifikasi' : 'Email belum terverifikasi',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: verified
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFEF6C00),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  /// `avatarUrl` bisa berupa URL absolut (dari PUBLIC_BASE_URL) atau path
  /// relatif `/uploads/...` yang dikembalikan `POST /upload/single`.
  String _avatarUrl(Map<String, dynamic> user) =>
      _absoluteUrl((user['avatarUrl'] ?? '').toString());

  /// Path relatif dari `POST /upload/single` (`/uploads/...`) → URL absolut
  /// memakai origin API. URL absolut dibiarkan apa adanya.
  String _absoluteUrl(String raw) {
    final String value = raw.trim();

    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final Uri base = Uri.parse(ApiConfig.baseUrl);
    // `hasPort` mencegah ":443" ikut tertulis pada URL https standar.
    final String origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';

    return value.startsWith('/') ? '$origin$value' : '$origin/$value';
  }

  Widget _buildAvatarImage(Map<String, dynamic> user, String name) {
    final String avatar = _avatarUrl(user);

    if (avatar.isEmpty) return _buildInitialsAvatar(name);

    return Image.network(
      avatar,
      fit: BoxFit.cover,
      // Foto lama bisa 404 setelah file dihapus: kembali ke inisial.
      errorBuilder: (_, _, _) => _buildInitialsAvatar(name),
    );
  }

  Widget _buildInitialsAvatar(String name, {double size = 84}) {
    return Container(
      color: const Color(0xFFEAF2FF),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: const Color(0xFF3478F6),
          // Avatar admin sekolah jauh lebih kecil dari avatar profil.
          fontSize: size <= 40 ? 12 : 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showAvatarOptions() async {
    if (_isUploadingAvatar) return;

    if (_avatarUrl(_user ?? const <String, dynamic>{}).isEmpty) {
      await _pickAvatar();
      return;
    }

    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF3478F6),
              ),
              title: const Text('Ganti foto'),
              onTap: () => Navigator.pop(sheetContext, 'change'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: _accent,
              ),
              title: const Text('Hapus foto'),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'change') await _pickAvatar();
    if (action == 'remove') await _removeAvatar();
  }

  /// Pilih dari galeri → unggah ke `POST /upload/single` → simpan URL-nya di
  /// profil lewat `PATCH /users/me { avatarUrl }`.
  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (file == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final Map<String, dynamic> uploaded = await ApiClient.uploadFile(
        ApiConfig.uploadSingle,
        filePath: file.path,
        fields: const <String, String>{'category': 'profile'},
      );

      final String url = (uploaded['url'] ?? uploaded['path'] ?? '')
          .toString()
          .trim();

      if (url.isEmpty) {
        throw const ApiException('Server tidak mengembalikan URL gambar.');
      }

      await ApiClient.patch(
        ApiConfig.updateProfile,
        body: <String, dynamic>{'avatarUrl': url},
      );

      if (!mounted) return;

      setState(() => _user = <String, dynamic>{...?_user, 'avatarUrl': url});
      _showSnack('Foto profil diperbarui.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Gagal mengunggah foto: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);

    try {
      await ApiClient.patch(
        ApiConfig.updateProfile,
        body: <String, dynamic>{'avatarUrl': null},
      );

      if (!mounted) return;

      setState(() => _user = <String, dynamic>{...?_user, 'avatarUrl': null});
      _showSnack('Foto profil dihapus.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Gagal menghapus foto: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// Badge kecil berisi jumlah notifikasi yang belum dibaca.
  Widget _buildUnreadBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isLoggingOut ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF3478F6), size: 22),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF303030),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9E9E9E),
                      size: 24,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _handleLogout,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          _isLoggingOut ? 'Keluar…' : 'Keluar',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// Huruf depan nama untuk avatar: "Budi Santoso" → "BS".
  String _initials(String name) {
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// `createdAt` dari API berupa ISO-8601; tampilkan sebagai "12 Nov 2026".
  String _formatDate(dynamic value) {
    final DateTime? date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return '';

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final DateTime local = date.toLocal();

    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
