import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/notifikasi/notifikasi.dart';
import 'package:ecocash_sekolah/profile/profile.dart';
import 'package:ecocash_sekolah/refund/refund.dart';
import 'package:ecocash_sekolah/saldo/saldo.dart';
import 'package:ecocash_sekolah/setor_sampah/scan.dart';
import 'package:ecocash_sekolah/transfer/transfer.dart';
import 'package:ecocash_sekolah/app_footer.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // PALET WARNA & KONSTANTA STYLING (DESIGN TOKENS)
  // ============================================================
  static const Color _bgMintTop = Color(0xFFEAF5EE);
  static const Color _bgMintBottom = Color(0xFFF7FAF8);
  static const Color _primaryGreen = Color(0xFF16A34A);
  static const Color _primaryGreenDark = Color(0xFF15803D);
  static const Color _primaryBlue = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF334155);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE6EFEA);

  // ============================================================
  // USER DATA FUTURE
  // ============================================================

  late Future<Map<String, dynamic>> _userDataFuture;

  /// Jumlah sesi yang belum dikonfirmasi (`meta.total` dari
  /// `GET /machine-sessions/my?status=WAITING_CONFIRMATION`).
  ///
  /// Hanya dipakai sebagai badge di menu "Riwayat Setor": daftar sesi aktifnya
  /// sendiri sekarang ada di dalam halaman riwayat.
  int _unconfirmedSessions = 0;

  /// Notifikasi in-app yang belum dibaca (`unreadCount` dari
  /// `GET /notifications`), untuk badge di lonceng header.
  int _unreadNotifications = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _userDataFuture = _fetchUserData();
  }

  // ============================================================
  // FETCH PROFILE + WALLET + CARBON
  // ============================================================

  Future<Map<String, dynamic>> _fetchUserData() async {
    // ==========================================================
    // TOKEN CHECK
    // ==========================================================

    if (!ApiConfig.hasToken) {
      throw const ApiException(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }

    // ==========================================================
    // REQUEST BERSAMAAN
    // ==========================================================

    /*
     * Profile, wallet dan carbon diambil secara bersamaan supaya Home
     * tidak melakukan request satu per satu.
     *
     * ApiClient sudah menangani timeout, envelope `{ data }`, status
     * non-200 (dilempar sebagai ApiException berisi pesan server) dan
     * 401 (token dihapus + ApiClient.onUnauthorized mengarahkan ke
     * halaman login).
     */

    final List<dynamic> results = await Future.wait<dynamic>([
      ApiClient.getMap(ApiConfig.getUserProfile),
      ApiClient.getMap(ApiConfig.getMyWallet),
      ApiClient.getMap(ApiConfig.getMyCarbon),
      // Badge menu "Riwayat Setor"; tidak boleh menggagalkan Home.
      _fetchUnconfirmedSessionCount(),
      // Badge lonceng notifikasi; juga tidak boleh menggagalkan Home.
      _fetchUnreadNotificationCount(),
    ]);

    final Map<String, dynamic> profileData = results[0] as Map<String, dynamic>;

    final Map<String, dynamic> walletData = results[1] as Map<String, dynamic>;

    final Map<String, dynamic> carbonData = results[2] as Map<String, dynamic>;

    _unconfirmedSessions = results[3] as int;

    _unreadNotifications = results[4] as int;

    // ==========================================================
    // MERGE DATA
    // ==========================================================

    /*
     * Struktur hasil dibuat sama seperti EcoCash Indonesia.
     *
     * Wallet:
     * - balance
     * - points
     *
     * Profile:
     * - name
     * - username
     * - email
     * - dll
     *
     * Carbon:
     * - totalSavedKg
     * - totalWasteKg
     * - transactions
     * - trend
     */

    return {
      // ========================================================
      // WALLET
      // ========================================================
      ...walletData,

      // ========================================================
      // PROFILE
      // ========================================================
      ...profileData,

      // ========================================================
      // CARBON
      // ========================================================
      'carbon': carbonData['totalSavedKg'] ?? carbonData['carbon'] ?? 0,

      'carbonUnit': carbonData['unit'] ?? 'kg CO2e',

      'carbonChange': carbonData['changePercent'] ?? 0,

      'totalWasteKg': carbonData['totalWasteKg'] ?? 0,

      'carbonTransactions': carbonData['transactions'] ?? 0,

      'carbonTrend': carbonData['trend'] ?? [],
    };
  }

  // ============================================================
  // REFRESH DATA
  // ============================================================

  Future<void> _refreshData() async {
    debugPrint('');
    debugPrint('REFRESH HOME ECOCASH SEKOLAH');
    debugPrint('');

    final Future<Map<String, dynamic>> newFuture = _fetchUserData();

    /*
     * FutureBuilder harus diberikan Future baru.
     *
     * Pada kode Sekolah lama:
     *
     * await _fetchUserData();
     *
     * memang melakukan request,
     * tetapi FutureBuilder tidak menerima data baru.
     *
     * Sekarang diperbaiki seperti EcoCash Indonesia.
     */

    setState(() {
      _userDataFuture = newFuture;
    });

    await newFuture;
  }

  // Nama pengguna mengikuti prioritas EcoCash Indonesia.
  String _getUserName(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final username = data['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? username : 'Pengguna';
  }

  // Inisial nama untuk avatar badge di header (helper tampilan murni).
  String _getUserInitials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ============================================================
  // FORMAT CARBON
  // ============================================================

  String _formatCarbon(dynamic value) {
    if (value == null) {
      return '0';
    }

    final double number = double.tryParse(value.toString()) ?? 0;

    /*
     * 10.0 menjadi 10
     */

    if (number == number.truncateToDouble()) {
      return number.toInt().toString();
    }

    /*
     * Maksimal 2 digit decimal.
     */

    return number.toStringAsFixed(2);
  }

  // ============================================================
  // FORMAT BALANCE
  // ============================================================

  String _formatBalance(dynamic value) {
    if (value == null) {
      return 'Rp0';
    }

    final double number = double.tryParse(value.toString()) ?? 0;

    final int integerValue = number.toInt();

    final String formatted = integerValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) {
        return '${match[1]}.';
      },
    );

    return 'Rp$formatted';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bgMintBottom,

        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgMintTop, _bgMintBottom],
              stops: [0.0, 0.55],
            ),
          ),
          child: SafeArea(
            top: false,

            // ======================================================
            // PULL TO REFRESH
            // ======================================================
            child: RefreshIndicator(
              color: _primaryGreen,
              onRefresh: _refreshData,

              child: FutureBuilder<Map<String, dynamic>>(
                future: _userDataFuture,

                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<Map<String, dynamic>> snapshot,
                    ) {
                      // ================================================
                      // LOADING
                      // ================================================

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _primaryGreen,
                          ),
                        );
                      }

                      // ================================================
                      // ERROR
                      // ================================================

                      if (snapshot.hasError) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),

                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height,

                            child: _buildErrorView(
                              context,
                              snapshot.error.toString(),
                            ),
                          ),
                        );
                      }

                      // ================================================
                      // NO DATA
                      // ================================================

                      if (!snapshot.hasData) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),

                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height,

                            child: _buildErrorView(
                              context,
                              'Data pengguna tidak tersedia',
                            ),
                          ),
                        );
                      }

                      // ================================================
                      // SUCCESS DATA
                      // ================================================

                      final Map<String, dynamic> data = snapshot.data ?? {};

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==========================================
                            // HEADER (DINAMIS ANTI-OVERLAP)
                            // ==========================================
                            _buildHeader(context, data),

                            const SizedBox(height: 24),

                            // ==========================================
                            // MENU
                            // ==========================================
                            _buildCombinedPaymentMenu(context),

                            const SizedBox(height: 36),

                            // ==========================================
                            // FOOTER
                            // ==========================================
                            const AppFooter(),

                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 44,
                color: Colors.redAccent,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Terjadi Kesalahan',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),

              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  /*
   * TAMPILAN TETAP ECOCASH SEKOLAH.
   *
   * Tetap menggunakan:
   *
   * assets/bg8.png
   *
   * Tidak menggunakan bg.png EcoCash Indonesia.
   */

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    final double topInset = MediaQuery.of(context).padding.top;
    final String userName = _getUserName(data);
    final String initials = _getUserInitials(userName);

    return Stack(
      children: [
        // ======================================================
        // BACKGROUND SEKOLAH
        // ======================================================
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 310 + topInset,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/bg8.png'),

                    fit: BoxFit.cover,

                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              // Gradasi halus di bagian bawah ilustrasi agar menyatu ke latar
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _bgMintTop.withValues(alpha: 0.0),
                        _bgMintTop.withValues(alpha: 0.85),
                        _bgMintTop,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // KONTEN FOREGROUND HEADER + BALANCE CARD
        // ======================================================
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BARIS ATAS: USER PILL CHIP & NOTIFICATION BELL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar Inisial Pengguna
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0EA5E9), _primaryBlue],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Eco Hero',
                                      style: TextStyle(
                                        color: _primaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.eco_rounded,
                                      size: 12,
                                      color: _primaryGreen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // NOTIFICATION BELL
                  _buildNotificationBell(),
                ],
              ),

              // Ruang bernapas agar ilustrasi maskot tetap terlihat jelas
              const SizedBox(height: 110),

              // Sapaan seperti Home EcoCash Indonesia, memakai data profil API.
              // Sisakan ruang di kanan agar tidak menutupi maskot pada bg8.png.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hai, $userName!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Siap untuk mendaur ulang hari ini?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.eco_rounded,
                            size: 14,
                            color: _primaryGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ======================================================
              // BALANCE CARD
              // ======================================================
              _buildBalanceCard(context, data),
            ],
          ),
        ),
      ],
    );
  }

  /// Lonceng notifikasi di header, lengkap dengan jumlah yang belum dibaca.
  ///
  /// Jumlahnya datang dari `GET /notifications?limit=1` (field `unreadCount`)
  /// yang diambil bersama request Home lainnya, lalu diperbarui lagi setelah
  /// pengguna kembali dari daftar notifikasi.
  Widget _buildNotificationBell() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.96),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _openNotifications,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: _textPrimary,
                  size: 23,
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -6,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        _unreadNotifications > 9
                            ? '9+'
                            : '$_unreadNotifications',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: _cardBorder, width: 1),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),

            blurRadius: 24,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          // ====================================================
          // BALANCE
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wadah ikon dompet dengan aksen lembut agar ikon aset tetap tajam
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
                ),
                child: Image.asset(
                  'assets/icons/dompet.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SALDO TABUNGAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,

                      alignment: Alignment.centerLeft,

                      child: Text(
                        _formatBalance(data['balance']),

                        maxLines: 1,

                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Badge status EcoCash
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 6, height: 6),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'EcoCash',
                      style: TextStyle(
                        color: _primaryGreenDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ====================================================
          // CARBON + POINT
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              // =================================================
              // CARBON
              // =================================================
              Expanded(
                child: _buildStatItem(
                  label: 'KARBON DISIMPAN',

                  value: '${_formatCarbon(data['carbon'])} kg CO₂e',

                  path: 'assets/icons/daun.png',

                  badgeBgColor: const Color(0xFFDCFCE7),

                  badgeBorderColor: const Color(0xFFBBF7D0),
                ),
              ),

              const SizedBox(width: 12),

              // =================================================
              // POINT
              // =================================================
              Expanded(
                child: _buildStatItem(
                  label: 'TOTAL POINT',

                  value: '${data['points'] ?? '0'}',

                  path: 'assets/icons/star.png',

                  badgeBgColor: const Color(0xFFFEF3C7),

                  badgeBorderColor: const Color(0xFFFDE68A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          const SizedBox(height: 16),

          // ====================================================
          // ACTION MENU
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // =================================================
              // SCAN BARCODE
              // =================================================
              Expanded(
                child: _buildActionItem(
                  path: 'assets/icons/scan.png',

                  label: 'Pindai QR',

                  tileBgColor: const Color(0xFFE0F2FE),

                  tileBorderColor: const Color(0xFFBAE6FD),

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return const ScanPage();
                        },
                      ),
                    ).then((_) {
                      /*
                         * Setelah setor sampah selesai,
                         * saldo, point dan carbon diperbarui.
                         */
                      _refreshData();
                    });
                  },
                ),
              ),

              // =================================================
              // TOP UP
              // =================================================
              Expanded(
                child: _buildActionItem(
                  path: 'assets/icons/topup.png',

                  label: 'Isi Ulang',

                  tileBgColor: const Color(0xFFEFF6FF),

                  tileBorderColor: const Color(0xFFDBEAFE),

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return const IsiSaldoPage();
                        },
                      ),
                    ).then((_) {
                      _refreshData();
                    });
                  },
                ),
              ),

              // =================================================
              // TRANSFER
              // =================================================
              Expanded(
                child: _buildActionItem(
                  path: 'assets/icons/panah.png',

                  label: 'Transfer',

                  tileBgColor: const Color(0xFFDCFCE7),

                  tileBorderColor: const Color(0xFFBBF7D0),

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return const TransferPage();
                        },
                      ),
                    ).then((_) {
                      _refreshData();
                    });
                  },
                ),
              ),

              // =================================================
              // HISTORY
              // =================================================
              Expanded(
                child: _buildActionItem(
                  path: 'assets/icons/lock.png',

                  label: 'Riwayat',

                  tileBgColor: const Color(0xFFF0FDFA),

                  tileBorderColor: const Color(0xFFCCFBF1),

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return const RefundsScreen();
                        },
                      ),
                    ).then((_) {
                      _refreshData();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION ITEM
  // ============================================================

  Widget _buildActionItem({
    required String path,
    required String label,
    required Color tileBgColor,
    required Color tileBorderColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tileBgColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: tileBorderColor, width: 1),
                ),
                child: Image.asset(path, fit: BoxFit.contain),
              ),

              const SizedBox(height: 8),

              Text(
                label,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STAT ITEM
  // ============================================================

  Widget _buildStatItem({
    required String label,
    required String value,
    required String path,
    required Color badgeBgColor,
    required Color badgeBorderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: badgeBorderColor, width: 1),
            ),
            child: Image.asset(path, fit: BoxFit.contain),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  label,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1.2,
                    color: _textMuted,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SESSION BADGE DATA
  // ============================================================

  /// Jumlah notifikasi yang belum dibaca (`unreadCount` dari
  /// `GET /notifications?limit=1`). Dibaca bersama request lain di Home, jadi
  /// tidak menambah waktu tunggu.
  Future<int> _fetchUnreadNotificationCount() async {
    try {
      final Map<String, dynamic> data = await ApiClient.getMap(
        '${ApiConfig.notifications}?page=1&limit=1',
      );

      final dynamic count = data['unreadCount'];

      return count is num ? count.toInt() : 0;
    } catch (error) {
      debugPrint('HOME unread notifications: $error');

      return 0;
    }
  }

  /// Buka daftar notifikasi; jumlah badge diperbarui setelah kembali.
  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotifikasiPage()),
    );

    if (!mounted) return;

    final int count = await _fetchUnreadNotificationCount();

    if (mounted) setState(() => _unreadNotifications = count);
  }

  /// Jumlah sesi `WAITING_CONFIRMATION` (yang masih bisa dikonfirmasi).
  Future<int> _fetchUnconfirmedSessionCount() async {
    try {
      final Map<String, dynamic> envelope = await ApiClient.getEnvelope(
        '${ApiConfig.getMySessionHistory}?status=WAITING_CONFIRMATION&limit=1',
      );

      final dynamic meta = envelope['meta'];

      if (meta is Map && meta['total'] is num) {
        return (meta['total'] as num).toInt();
      }

      final dynamic data = envelope['data'];

      return data is List ? data.length : 0;
    } catch (error) {
      debugPrint('HOME unconfirmed sessions: $error');

      return 0;
    }
  }

  /// Badge di kanan menu "Riwayat Setor": jumlah sesi yang belum
  /// dikonfirmasi. Daftarnya ada di dalam halaman riwayat.
  Widget? _openSessionBadge() {
    if (_unconfirmedSessions <= 0) return null;

    return Container(
      constraints: const BoxConstraints(minWidth: 22),

      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),

      decoration: BoxDecoration(
        color: const Color(0xFFE53935),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        _unconfirmedSessions > 9 ? '9+' : '$_unconfirmedSessions',

        textAlign: TextAlign.center,

        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // MENU SECTION
  // ============================================================

  Widget _buildCombinedPaymentMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ====================================================
          // TITLE
          // ====================================================
          const Text(
            'Menu',

            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 14),

          // ====================================================
          // SESSION HISTORY
          //
          // Sesi yang masih terbuka (sedang menimbang atau
          // menunggu konfirmasi) tampil di bagian atas halaman
          // riwayat, jadi tidak ada lagi menu "Sesi Aktif"
          // terpisah. Badge di sini hanya pengingat.
          // ====================================================
          _buildMenuCard(
            path: 'assets/icons/riwayat.png',

            title: 'Riwayat Setor',

            subtitle: _unconfirmedSessions > 0
                ? (_unconfirmedSessions == 1
                      ? '1 sesi menunggu konfirmasi'
                      : '$_unconfirmedSessions sesi menunggu konfirmasi')
                : 'Catatan pilah & setor sampahmu',

            badgeBgColor: const Color(0xFFE0F2FE),

            badgeBorderColor: const Color(0xFFBAE6FD),

            trailing: _openSessionBadge(),

            onTap: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return const RefundsScreen();
                  },
                ),
              ).then((_) {
                _refreshData();
              });
            },
          ),

          const SizedBox(height: 12),

          // ====================================================
          // PROFILE
          // ====================================================
          _buildMenuCard(
            path: 'assets/icons/plus.png',

            title: 'Profil',

            subtitle: 'Kelola akun dan info sekolah',

            badgeBgColor: const Color(0xFFCCFBF1),

            badgeBorderColor: const Color(0xFF99F6E4),

            onTap: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return const ProfilePage();
                  },
                ),
              ).then((_) {
                /*
                 * Profile bisa berubah.
                 */
                _refreshData();
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU CARD
  // ============================================================

  Widget _buildMenuCard({
    required String path,
    required String title,
    required Color badgeBgColor,
    required Color badgeBorderColor,
    VoidCallback? onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: badgeBorderColor, width: 1),
                  ),
                  child: Image.asset(path, fit: BoxFit.contain),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (trailing != null) ...[const SizedBox(width: 8), trailing],

                const SizedBox(width: 8),

                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
