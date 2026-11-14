import 'package:ecocash_sekolah/app_footer.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/refund/session_export.dart';
import 'package:ecocash_sekolah/setor_sampah/konfirmasi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  /// Ukuran halaman. Sama dengan default server, jadi `page`/`limit` konsisten
  /// dan `meta.totalPages` bisa dipakai langsung.
  static const int _pageSize = 10;

  /// Baris yang sudah dimuat (bertambah setiap halaman berikutnya).
  final List<Map<String, dynamic>> _sessions = [];

  /// Sesi yang masih terbuka (`ACTIVE` / `WAITING_CONFIRMATION`).
  ///
  /// Ditampilkan di atas riwayat dan **hanya bila ada isinya** — pengguna
  /// tidak perlu melihat bagian kosong saat tidak sedang menyetor.
  final List<Map<String, dynamic>> _activeSessions = [];

  /// Rincian item per sesi, dimuat saat baris dibuka lalu di-cache.
  ///
  /// Dimuat lazy supaya daftar riwayat tetap ringan (bukan N+1 lagi):
  /// `GET /machine-sessions/{id}` hanya dipanggil untuk sesi yang benar-benar
  /// dibuka pengguna.
  final Map<int, Future<List<Map<String, dynamic>>>> _itemsCache = {};

  final ScrollController _scrollController = ScrollController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Halaman yang sedang ditampilkan (1-based) dan totalnya dari `meta`.
  int _page = 1;
  int _totalPages = 1;
  int _totalSessions = 0;

  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  Object? _error;

  /// Sedang menyiapkan file CSV (mengambil semua halaman + menulis file).
  bool _isExporting = false;

  /// Progres ekspor: baris terkumpul / total menurut `meta.total`.
  int _exportLoaded = 0;
  int _exportTotal = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _loadFirstPage();

    _loadActiveSessions();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();

    super.dispose();
  }

  // ============================================================
  // FETCH SESSION HISTORY
  // ============================================================

  /// Satu halaman riwayat + `meta` (total & totalPages) dari server.
  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final Map<String, dynamic> envelope = await ApiClient.getEnvelope(
      '${ApiConfig.getMySessionHistory}?page=$page&limit=$_pageSize',
    );

    final dynamic data = envelope['data'];

    final List<Map<String, dynamic>> rows = data is List
        ? data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final dynamic meta = envelope['meta'];

    if (meta is Map) {
      _totalPages = meta['totalPages'] is num
          ? (meta['totalPages'] as num).toInt()
          : page;

      _totalSessions = meta['total'] is num
          ? (meta['total'] as num).toInt()
          : rows.length;
    } else {
      _totalPages = page;

      _totalSessions = rows.length;
    }

    return rows;
  }

  Future<void> _loadFirstPage() async {
    // Rincian item bisa bertambah selama sesinya masih ACTIVE.
    _itemsCache.clear();

    if (mounted) {
      setState(() {
        // Saat pull-to-refresh daftar lama tetap tampil.
        _isLoadingFirstPage = _sessions.isEmpty;

        _error = null;
      });
    }

    try {
      final List<Map<String, dynamic>> rows = await _fetchPage(1);

      if (!mounted) return;

      setState(() {
        _sessions
          ..clear()
          ..addAll(rows);

        _page = 1;

        _isLoadingFirstPage = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingFirstPage = false;

        _error = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoadingFirstPage || _page >= _totalPages) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final List<Map<String, dynamic>> rows = await _fetchPage(_page + 1);

      if (!mounted) return;

      setState(() {
        // Buang duplikat bila ada sesi baru masuk di antara dua halaman.
        final Set<String> known = _sessions
            .map((session) => '${session['id']}')
            .toSet();

        _sessions.addAll(
          rows.where((row) => !known.contains('${row['id']}')),
        );

        _page += 1;

        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoadingMore = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat sesi berikutnya: $error')),
      );
    }
  }

  /// Halaman berikutnya dimuat otomatis saat mendekati dasar daftar.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final ScrollPosition position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Map<String, dynamic> _extractMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // REFRESH
  // ============================================================

  /// Pull-to-refresh dan tombol "Coba Lagi" selalu mulai dari halaman 1.
  /// Sesi yang masih terbuka ikut disegarkan karena tampil di atas daftar.
  Future<void> _refreshSessions() async {
    await Future.wait<void>([_loadFirstPage(), _loadActiveSessions()]);
  }

  // ============================================================
  // ACTIVE SESSIONS (bagian atas halaman)
  // ============================================================

  /// Dua status diambil paralel: `status` hanya menerima satu nilai per
  /// request, sedangkan sesi `ACTIVE` (mesin sedang menimbang) juga perlu
  /// tampil walau prioritasnya di bawah `WAITING_CONFIRMATION`.
  Future<void> _loadActiveSessions() async {
    try {
      final List<dynamic> payloads = await Future.wait<dynamic>([
        ApiClient.get(
          '${ApiConfig.getMySessionHistory}'
          '?status=WAITING_CONFIRMATION&limit=50',
        ),
        ApiClient.get(
          '${ApiConfig.getMySessionHistory}?status=ACTIVE&limit=50',
        ),
      ]);

      final List<Map<String, dynamic>> sessions = [];

      for (final dynamic payload in payloads) {
        if (payload is! List) continue;

        for (final dynamic row in payload) {
          if (row is Map) sessions.add(Map<String, dynamic>.from(row));
        }
      }

      // Yang uangnya menunggu didahulukan, lalu yang paling baru.
      sessions.sort((a, b) {
        final int rankA = _activeRank(a['status']);
        final int rankB = _activeRank(b['status']);

        if (rankA != rankB) return rankA.compareTo(rankB);

        return _sessionDate(b['startedAt']).compareTo(_sessionDate(a['startedAt']));
      });

      if (!mounted) return;

      setState(() {
        _activeSessions
          ..clear()
          ..addAll(sessions);
      });
    } catch (error) {
      // Bagian tambahan: kegagalannya tidak boleh mengganggu riwayat.
      debugPrint('Gagal memuat sesi aktif: $error');
    }
  }

  int _activeRank(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'WAITING_CONFIRMATION':
        return 0;
      case 'ACTIVE':
        return 1;
      default:
        return 2;
    }
  }

  DateTime _sessionDate(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _openActiveSession(int sessionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          return SetorSampahScreen(sessionId: sessionId);
        },
      ),
    );

    if (!mounted) return;

    // Sesi bisa berubah status (dikonfirmasi / dibatalkan) setelah layar itu.
    await _refreshSessions();
  }

  Widget _buildActiveSessionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                size: 18,
                color: Color(0xFFEF6C00),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sesi Aktif',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E50),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_activeSessions.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF6C00),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          for (final Map<String, dynamic> session in _activeSessions) ...[
            _buildActiveSessionCard(session),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(Map<String, dynamic> session) {
    final String status = (session['status'] ?? '').toString().toUpperCase();

    final bool waiting = status == 'WAITING_CONFIRMATION';

    final int? sessionId = int.tryParse('${session['id'] ?? ''}');

    final double weight = _toDouble(session['currentWeight']);

    final double price = _toDouble(session['totalPrice']);

    final Color accent = waiting
        ? const Color(0xFFEF6C00)
        : const Color(0xFF1976D2);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: sessionId == null ? null : () => _openActiveSession(sessionId),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.25)),
            color: waiting ? const Color(0xFFFFF8EE) : const Color(0xFFF2F7FD),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  waiting
                      ? Icons.pending_actions_rounded
                      : Icons.scale_rounded,
                  color: accent,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? 'Menunggu konfirmasi' : 'Sedang menimbang',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_getMachineName(session)} · '
                      '${_formatDate(session['startedAt'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF7A8A9A),
                      ),
                    ),
                    if (weight > 0 || price > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${weight.toStringAsFixed(2)} kg · '
                        '${_currencyFormat.format(price)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A6A7A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UNDUH RIWAYAT (CSV)
  // ============================================================

  /// Unduh **seluruh** riwayat setor sebagai CSV lalu buka share sheet.
  ///
  /// Berbeda dari daftar di layar yang bertambah per halaman, ekspor
  /// mengambil semua halaman dari server supaya file-nya utuh.
  Future<void> _exportHistory() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _exportLoaded = 0;
      _exportTotal = 0;
    });

    try {
      final SessionExportResult result =
          await SessionHistoryExporter.exportToCsv(
            onProgress: (loaded, total) {
              if (!mounted) return;

              setState(() {
                _exportLoaded = loaded;
                _exportTotal = total;
              });
            },
          );

      if (!mounted) return;

      setState(() {
        _isExporting = false;
        _exportLoaded = 0;
        _exportTotal = 0;
      });

      if (result.isEmpty) {
        _showMessage('Belum ada riwayat untuk diunduh.');
        return;
      }

      if (result.shared) {
        _showMessage(
          '${result.sessionCount} sesi disiapkan sebagai ${result.fileName}.',
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _isExporting = false;
        _exportLoaded = 0;
        _exportTotal = 0;
      });

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isExporting = false;
        _exportLoaded = 0;
        _exportTotal = 0;
      });

      _showMessage('Gagal membuat file CSV. Coba lagi.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // FORMAT DATA
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    try {
      final DateTime date = DateTime.parse(value.toString()).toLocal();

      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatSessionDate(Map<String, dynamic> session) {
    final dynamic dateValue = session['startedAt'] ?? session['createdAt'];

    return _formatDate(dateValue);
  }

  String _getMachineName(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String name = machine['name']?.toString().trim() ?? '';

    return name.isNotEmpty ? name : 'Mesin tidak diketahui';
  }

  String _getMachineCode(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String machineCode = machine['machineCode']?.toString().trim() ?? '';

    return machineCode.isNotEmpty ? machineCode : '-';
  }

  String _getMachineLocation(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String placeName = machine['placeName']?.toString().trim() ?? '';

    final String address = machine['address']?.toString().trim() ?? '';

    final String subdistrict = machine['subdistrict']?.toString().trim() ?? '';

    final String district = machine['district']?.toString().trim() ?? '';

    if (placeName.isNotEmpty && address.isNotEmpty) {
      return '$placeName, $address';
    }

    if (address.isNotEmpty) {
      return address;
    }

    if (placeName.isNotEmpty) {
      return placeName;
    }

    final List<String> locationParts = [
      subdistrict,
      district,
    ].where((value) => value.isNotEmpty).toList();

    if (locationParts.isNotEmpty) {
      return locationParts.join(', ');
    }

    return 'Lokasi tidak tersedia';
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Sedang Berlangsung';

      case 'WAITING_CONFIRMATION':
        return 'Menunggu Konfirmasi';

      case 'COMPLETED':
        return 'Selesai';

      case 'CANCELLED':
        return 'Dibatalkan';

      case 'EXPIRED':
        return 'Kedaluwarsa';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF1976D2);

      case 'WAITING_CONFIRMATION':
        return const Color(0xFFF57C00);

      case 'COMPLETED':
        return const Color(0xFF2E7D32);

      case 'CANCELLED':
      case 'EXPIRED':
        return const Color(0xFFC62828);

      default:
        return const Color(0xFF757575);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _refreshSessions,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, _sessions),

              const SizedBox(height: 140),

              // Hanya tampil bila memang ada sesi yang masih terbuka.
              if (_activeSessions.isNotEmpty) ...[
                _buildActiveSessionsSection(),
                const SizedBox(height: 16),
              ],

              if (_isLoadingFirstPage)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null)
                _buildErrorState(_error.toString())
              else if (_sessions.isEmpty)
                _buildEmptyState()
              else ...[
                _buildSessionList(_sessions),

                _buildPaginationFooter(),
              ],

              const SizedBox(height: 24),
              const AppFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGINATION FOOTER
  // ============================================================

  Widget _buildPaginationFooter() {
    final bool hasMore = _page < _totalPages;

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
      child: Column(
        children: [
          Text(
            hasMore
                ? 'Menampilkan ${_sessions.length} dari $_totalSessions sesi'
                : 'Semua $_totalSessions sesi sudah ditampilkan',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),

          if (hasMore) ...[
            const SizedBox(height: 10),

            if (_isLoadingMore)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  'Muat ${_remainingCount()} sesi berikutnya',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  int _remainingCount() {
    final int remaining = _totalSessions - _sessions.length;

    if (remaining <= 0) return 0;

    return remaining < _pageSize ? remaining : _pageSize;
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 50),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshSessions,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            'Belum ada riwayat sesi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SESSION LIST
  // ============================================================

  Widget _buildSessionList(List<Map<String, dynamic>> sessions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildListHeader(),

              ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (context, index) {
                  return const Divider(height: 1);
                },
                itemBuilder: (context, index) {
                  return _buildSessionItem(sessions[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final String status = session['status']?.toString() ?? 'UNKNOWN';

    final int? sessionId = int.tryParse('${session['id'] ?? ''}');

    final Color statusColor = _statusColor(status);

    final double currentWeight = _toDouble(session['currentWeight']);

    final double totalPrice = _toDouble(session['totalPrice']);

    final String machineName = _getMachineName(session);

    final String machineCode = _getMachineCode(session);

    final String machineLocation = _getMachineLocation(session);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.recycling_rounded, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          machineName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            _formatSessionDate(session),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _detailRow(
                  label: 'ID Sesi',
                  value: sessionId?.toString() ?? '-',
                ),

                const Divider(height: 22),

                _detailRow(label: 'Kode Mesin', value: machineCode),

                const Divider(height: 22),

                _detailRow(label: 'Lokasi', value: machineLocation),

                const Divider(height: 22),

                _detailRow(
                  label: 'Berat Sampah',
                  value: '${currentWeight.toStringAsFixed(2)} kg',
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Pendapatan',
                  value: _currencyFormat.format(totalPrice),
                  valueColor: const Color(0xFF107569),
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Mulai',
                  value: _formatDate(
                    session['startedAt'] ?? session['createdAt'],
                  ),
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Selesai',
                  value: _formatDate(session['endedAt']),
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (sessionId != null) _buildItemsSection(sessionId),
        ],
      ),
    );
  }

  // ============================================================
  // ITEM DETAIL (lazy, saat baris dibuka)
  // ============================================================

  Future<List<Map<String, dynamic>>> _itemsFor(int sessionId) {
    return _itemsCache.putIfAbsent(sessionId, () async {
      final dynamic payload = await ApiClient.get(
        ApiConfig.getSessionDetail(sessionId.toString()),
      );

      if (payload is! Map) return <Map<String, dynamic>>[];

      final dynamic rawItems = payload['items'];

      if (rawItems is! List) return <Map<String, dynamic>>[];

      return rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    });
  }

  Widget _buildItemsSection(int sessionId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFor(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 14,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rincian item gagal dimuat: ${snapshot.error}',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        final List<Map<String, dynamic>> items = snapshot.data ?? const [];

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'Tidak ada item tercatat pada sesi ini.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Rincian Item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263238),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${items.length})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              ...items.map(_buildItemRow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final String name = item['wasteType']?.toString() ?? 'Material';

    final double weight = _toDouble(item['weight']);

    final double pricePerKg = _toDouble(item['pricePerKg']);

    final double totalPrice = _toDouble(item['totalPrice']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 7, color: Color(0xFF4CAF50)),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF263238),
                  ),
                ),
                Text(
                  '${weight.toStringAsFixed(2)} kg'
                  ' × ${_currencyFormat.format(pricePerKg)}/kg',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            _currencyFormat.format(totalPrice),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF107569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF263238),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: const BoxDecoration(color: Color(0xFFFFD966)),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Riwayat Sesi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildExportButton(),
        ],
      ),
    );
  }

  /// Tombol "Unduh CSV" di kanan header daftar riwayat.
  ///
  /// Menampilkan progres `terkumpul/total` selama halaman demi halaman
  /// diambil, lalu membuka share sheet berisi file CSV.
  Widget _buildExportButton() {
    final String label = _isExporting
        ? (_exportTotal > 0
              ? '$_exportLoaded/$_exportTotal'
              : 'Menyiapkan...')
        : 'Unduh CSV';

    return Material(
      color: const Color(0x38FFFFFF),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isExporting ? null : _exportHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isExporting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    BuildContext context,
    List<Map<String, dynamic>> sessions,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg4.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 25, left: 20),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -110,
          left: 15,
          right: 15,
          child: _buildSummaryCard(sessions),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> sessions) {
    /*
     * "Total Sesi" memakai `meta.total` (seluruh sesi di server), sedangkan
     * berat & pendapatan hanya bisa dijumlahkan dari baris yang sudah dimuat -
     * karena itu ada catatan kecil selama masih ada halaman lain.
     */
    final int loadedSessions = sessions.length;

    final int totalSessions = _totalSessions > 0
        ? _totalSessions
        : loadedSessions;

    final double totalWeight = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['currentWeight']);
    });

    final double totalEarnings = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['totalPrice']);
    });

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset('assets/icons/mingcute.png', width: 45, height: 45),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Session History',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                Image.asset('assets/icons/share.png', width: 42, height: 42),
              ],
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                _buildInfoBox(
                  'Total Sesi',
                  totalSessions.toString(),
                  const Color(0xFFE6F9E6),
                ),

                const SizedBox(width: 10),

                _buildInfoBox(
                  'Total Berat',
                  '${totalWeight.toStringAsFixed(2)} kg',
                  const Color(0xFFE6F2FA),
                ),

                const SizedBox(width: 10),

                _buildInfoBox(
                  'Pendapatan',
                  _currencyFormat.format(totalEarnings),
                  const Color(0xFFFFF9E6),
                ),
              ],
            ),

            if (loadedSessions < totalSessions) ...[
              const SizedBox(height: 10),

              Text(
                '* Berat dan pendapatan dihitung dari '
                '$loadedSessions sesi terbaru.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 6),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
