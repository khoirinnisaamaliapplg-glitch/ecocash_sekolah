import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail sekolah pengguna, termasuk admin yang mengelolanya.
///
/// Sumber: `GET /users/me/organization` →
/// `{ organization: { id, code, name, type, address, logoUrl, isActive },
///    admin: { id, name, phoneNumber, avatarUrl } }`.
///
/// Halaman profil sengaja hanya menampilkan satu baris ("Sekolah"), dan semua
/// detail + tombol kontak dipindahkan ke sini supaya kartu profil tetap ringkas.
class OrganisasiPage extends StatefulWidget {
  const OrganisasiPage({super.key, this.organization, this.admin});

  /// Nilai awal dari halaman profil. Boleh null: halaman ini akan mengambil
  /// sendiri dari API, jadi tetap bisa dibuka walau profil gagal memuatnya.
  final Map<String, dynamic>? organization;
  final Map<String, dynamic>? admin;

  @override
  State<OrganisasiPage> createState() => _OrganisasiPageState();
}

class _OrganisasiPageState extends State<OrganisasiPage> {
  static const Color _accent = Color(0xFFE53935);

  Map<String, dynamic>? _organization;
  Map<String, dynamic>? _admin;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _organization = widget.organization;
    _admin = widget.admin;

    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        // Data awal dari profil tetap tampil; spinner hanya saat kosong.
        _isLoading = _organization == null;
        _error = null;
      });
    }

    try {
      final Map<String, dynamic> data = await ApiClient.getMap(
        ApiConfig.myOrganization,
      );

      if (!mounted) return;

      setState(() {
        _organization = _asMap(data['organization']);
        _admin = _asMap(data['admin']);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Gagal memuat data sekolah: $e';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  /// Path relatif (`/uploads/...`) → absolut memakai origin API.
  String _absoluteUrl(String raw) {
    final String value = raw.trim();

    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final Uri base = Uri.parse(ApiConfig.baseUrl);
    final String origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';

    return value.startsWith('/') ? '$origin$value' : '$origin/$value';
  }

  /// `0812-3456-7890` → `6281234567890` (format yang diterima wa.me).
  String _waPhone(String phone) {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    if (digits.startsWith('62')) return digits;

    return digits;
  }

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

  /// `SEKOLAH_NEGERI` → `Sekolah negeri`.
  String _humanize(String value) {
    final String lower = value.replaceAll('_', ' ').toLowerCase();

    if (lower.isEmpty) return value;

    return lower[0].toUpperCase() + lower.substring(1);
  }

  Widget _initialsAvatar(String name, double size, {Color? background}) {
    return Container(
      width: size,
      height: size,
      color: background ?? const Color(0xFFEAF2FF),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: const Color(0xFF3478F6),
          fontSize: size <= 40 ? 13 : 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) _showMessage('Tidak ada aplikasi untuk membuka tautan ini.');
    } catch (_) {
      _showMessage('Tidak ada aplikasi untuk membuka tautan ini.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _accent,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 16),
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
              const Expanded(
                child: Text(
                  'Sekolah Saya',
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

  Widget _buildBody() {
    final Map<String, dynamic>? organization = _organization;

    if (_isLoading && organization == null) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (organization == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Icon(
            _error != null ? Icons.cloud_off_rounded : Icons.school_outlined,
            size: 52,
            color: const Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Akun Anda belum terhubung ke sekolah mana pun.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _buildSchoolCard(organization),
        const SizedBox(height: 14),
        _buildAdminCard(),
        const SizedBox(height: 16),
        const Text(
          'Hubungi admin sekolah untuk pertanyaan seputar setoran, saldo, atau '
          'kegiatan sekolah.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSchoolCard(Map<String, dynamic> organization) {
    final String name = (organization['name'] ?? '').toString().trim();
    final String type = (organization['type'] ?? '').toString().trim();
    final String code = (organization['code'] ?? '').toString().trim();
    final String address = (organization['address'] ?? '').toString().trim();
    final String logo = (organization['logoUrl'] ?? '').toString().trim();
    final bool active = organization['isActive'] != false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: logo.isEmpty
                      ? _initialsAvatar(
                          name,
                          56,
                          background: const Color(0xFFEAF2FF),
                        )
                      : Image.network(
                          _absoluteUrl(logo),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _initialsAvatar(
                            name,
                            56,
                            background: const Color(0xFFEAF2FF),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Sekolah' : name,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (type.isNotEmpty) _buildChip(_humanize(type)),
                        _buildChip(
                          active ? 'Aktif' : 'Tidak aktif',
                          color: active
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          background: active
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFDECEA),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (address.isNotEmpty || code.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 14),
          ],

          if (code.isNotEmpty) _buildInfoRow(Icons.badge_outlined, 'Kode', code),
          if (address.isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, 'Alamat', address),
        ],
      ),
    );
  }

  Widget _buildAdminCard() {
    final Map<String, dynamic>? admin = _admin;

    final String name = (admin?['name'] ?? '').toString().trim();
    final String phone = (admin?['phoneNumber'] ?? '').toString().trim();
    final String avatar = (admin?['avatarUrl'] ?? '').toString().trim();

    if (name.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF8A8A8A)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sekolah ini belum memiliki admin yang terdaftar.',
                style: TextStyle(color: Color(0xFF757575), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Sekolah',
            style: TextStyle(
              color: Color(0xFF2D3E50),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: avatar.isEmpty
                      ? _initialsAvatar(name, 46)
                      : Image.network(
                          _absoluteUrl(avatar),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _initialsAvatar(name, 46),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.isEmpty ? 'Admin sekolah' : phone,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExternal('tel:$phone'),
                    icon: const Icon(Icons.call_outlined, size: 17),
                    label: const Text('Telepon'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFFCFE3D5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openExternal('https://wa.me/${_waPhone(phone)}'),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    Color color = const Color(0xFF3478F6),
    Color background = const Color(0xFFEAF2FF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF8A8A8A)),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
