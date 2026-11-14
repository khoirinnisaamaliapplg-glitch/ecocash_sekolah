import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';

/// Daftar notifikasi in-app (`GET /notifications`).
///
/// Kontrak backend:
/// - `GET /notifications?page&limit&isRead` →
///   `{ notifications: [...], unreadCount, meta: { page, limit, totalItems, totalPages } }`
/// - `PATCH /notifications/:id/read` → satu notifikasi ditandai dibaca
/// - `PATCH /notifications/read-all` → semua milik pengguna ditandai dibaca
///
/// Push (FCM) belum dipakai di aplikasi ini: `PUT /notifications/fcm-token`
/// baru berguna setelah `firebase_messaging` ditambahkan. Layar ini membaca
/// riwayat yang disimpan server, jadi notifikasi tetap terlihat tanpa push.
class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  static const Color _accent = Color(0xFFE53935);
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  int _page = 1;
  int _totalPages = 1;
  int _unreadCount = 0;
  bool _onlyUnread = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<Map<String, dynamic>> _fetch(int page) {
    final String url =
        '${ApiConfig.notifications}?page=$page&limit=$_pageSize'
        '${_onlyUnread ? '&isRead=false' : ''}';

    return ApiClient.getMap(url);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final dynamic raw = data['notifications'];
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _totalPagesOf(Map<String, dynamic> data) {
    final dynamic meta = data['meta'];
    if (meta is Map && meta['totalPages'] is num) {
      return (meta['totalPages'] as num).toInt().clamp(1, 1 << 30);
    }
    return 1;
  }

  int _unreadOf(Map<String, dynamic> data) {
    final dynamic count = data['unreadCount'];
    return count is num ? count.toInt() : 0;
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final Map<String, dynamic> data = await _fetch(1);

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_rows(data));
        _page = 1;
        _totalPages = _totalPagesOf(data);
        _unreadCount = _unreadOf(data);
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
        _error = 'Gagal memuat notifikasi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _page >= _totalPages) return;

    setState(() => _isLoadingMore = true);

    try {
      final Map<String, dynamic> data = await _fetch(_page + 1);

      if (!mounted) return;
      setState(() {
        final Set<String> known = _items
            .map((item) => '${item['id']}')
            .toSet();

        // Idempoten: notifikasi baru bisa masuk di antara dua halaman.
        _items.addAll(
          _rows(data).where((item) => !known.contains('${item['id']}')),
        );

        _page += 1;
        _totalPages = _totalPagesOf(data);
        _unreadCount = _unreadOf(data);
      });
    } catch (e) {
      if (mounted) _showMessage('Gagal memuat notifikasi berikutnya.');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final double threshold =
        _scrollController.position.maxScrollExtent - 240;

    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['isRead'] == true) return;

    final int? id = int.tryParse('${item['id']}');
    if (id == null) return;

    /*
     * Optimistis: daftar langsung berubah, lalu server menyusul. Kalau gagal,
     * statusnya dikembalikan supaya titik "belum dibaca" tidak hilang diam-diam.
     */
    setState(() {
      final int index = _items.indexWhere((row) => row['id'] == item['id']);
      if (index >= 0) {
        _items[index] = <String, dynamic>{..._items[index], 'isRead': true};
      }
      if (_unreadCount > 0) _unreadCount -= 1;
    });

    try {
      await ApiClient.patch(ApiConfig.notificationRead(id));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final int index = _items.indexWhere((row) => row['id'] == item['id']);
        if (index >= 0) {
          _items[index] = <String, dynamic>{
            ..._items[index],
            'isRead': false,
          };
        }
        _unreadCount += 1;
      });

      _showMessage('Gagal menandai notifikasi sebagai dibaca.');
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;

    try {
      await ApiClient.patch(ApiConfig.notificationsReadAll);

      if (!mounted) return;

      setState(() {
        _unreadCount = 0;
        for (int i = 0; i < _items.length; i++) {
          _items[i] = <String, dynamic>{..._items[i], 'isRead': true};
        }
      });

      _showMessage('Semua notifikasi ditandai dibaca.');

      // Filter "belum dibaca" sekarang kosong: ambil ulang agar konsisten.
      if (_onlyUnread) await _loadFirstPage();
    } catch (e) {
      if (mounted) {
        _showMessage(
          e is ApiException ? e.message : 'Gagal menandai semua notifikasi.',
        );
      }
    }
  }

  void _setFilter(bool onlyUnread) {
    if (_onlyUnread == onlyUnread) return;

    setState(() => _onlyUnread = onlyUnread);
    _loadFirstPage();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // DETAIL
  // ============================================================

  Future<void> _openDetail(Map<String, dynamic> item) async {
    await _markRead(item);

    if (!mounted) return;

    final _TypeStyle style = _styleOf(item);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildTypeAvatar(style),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: TextStyle(
                              color: style.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _relativeTime(item['createdAt']),
                            style: const TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  (item['title'] ?? 'Notifikasi').toString(),
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      (item['body'] ?? '').toString(),
                      style: const TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  _TypeStyle _styleOf(Map<String, dynamic> item) {
    final String type = (item['type'] ?? 'SYSTEM').toString().toUpperCase();

    switch (type) {
      case 'WALLET_CREDIT':
        return const _TypeStyle(
          icon: Icons.account_balance_wallet_outlined,
          color: Color(0xFF2E7D32),
          label: 'SALDO',
        );
      case 'JOB_AVAILABLE':
      case 'JOB_STATUS_UPDATED':
        return const _TypeStyle(
          icon: Icons.local_shipping_outlined,
          color: Color(0xFF1565C0),
          label: 'PENJEMPUTAN',
        );
      case 'KYC_STATUS':
        return const _TypeStyle(
          icon: Icons.verified_user_outlined,
          color: Color(0xFF6A1B9A),
          label: 'VERIFIKASI',
        );
      case 'TICKET_UPDATE':
        return const _TypeStyle(
          icon: Icons.support_agent_rounded,
          color: Color(0xFFEF6C00),
          label: 'BANTUAN',
        );
      case 'CONTAINER_ALERT':
        return const _TypeStyle(
          icon: Icons.delete_outline_rounded,
          color: Color(0xFFC62828),
          label: 'MESIN',
        );
      default:
        return const _TypeStyle(
          icon: Icons.campaign_outlined,
          color: Color(0xFF37474F),
          label: 'INFO',
        );
    }
  }

  /// "Baru saja" / "5 menit lalu" / "2 jam lalu" / "3 hari lalu" / tanggal.
  String _relativeTime(dynamic value) {
    final DateTime? date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return '';

    final DateTime local = date.toLocal();
    final Duration diff = DateTime.now().difference(local);

    if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

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

    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
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
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 14),
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
                  'Notifikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    'Tandai semua',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF4A4A4A),
          ),
          backgroundColor: Colors.white,
          selectedColor: _accent,
          side: BorderSide(
            color: selected ? _accent : const Color(0xFFE3E3E3),
          ),
          showCheckmark: false,
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          chip('Semua', !_onlyUnread, () => _setFilter(false)),
          chip('Belum dibaca', _onlyUnread, () => _setFilter(true)),
          const Spacer(),
          if (_unreadCount > 0)
            Text(
              '$_unreadCount belum dibaca',
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 11.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Icon(
            _onlyUnread
                ? Icons.mark_email_read_outlined
                : Icons.notifications_none_rounded,
            size: 52,
            color: const Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 14),
          Text(
            _onlyUnread
                ? 'Tidak ada notifikasi yang belum dibaca.'
                : 'Belum ada notifikasi.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Notifikasi tentang setoran, saldo, dan promo akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12.5),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: _items.length + (_page < _totalPages ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _accent,
                ),
              ),
            ),
          );
        }

        return _buildTile(_items[index]);
      },
    );
  }

  Widget _buildTile(Map<String, dynamic> item) {
    final bool unread = item['isRead'] != true;
    final _TypeStyle style = _styleOf(item);
    final String body = (item['body'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetail(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeAvatar(style),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (item['title'] ?? 'Notifikasi').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF212121),
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(item['createdAt']),
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeAvatar(_TypeStyle style) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(style.icon, color: style.color, size: 21),
    );
  }
}

/// Ikon + warna + label per `NotificationType` dari backend.
class _TypeStyle {
  const _TypeStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}
