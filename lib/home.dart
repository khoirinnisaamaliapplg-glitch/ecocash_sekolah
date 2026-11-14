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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        top: false,

        // ======================================================
        // PULL TO REFRESH
        // ======================================================
        child: RefreshIndicator(
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
                    return const Center(child: CircularProgressIndicator());
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
                      children: [
                        // ==========================================
                        // HEADER
                        // ==========================================
                        SizedBox(
                          height: 450,

                          child: _buildHeader(context, data),
                        ),

                        const SizedBox(height: 40),

                        // ==========================================
                        // MENU
                        // ==========================================
                        _buildCombinedPaymentMenu(context),

                        const SizedBox(height: 50),

                        // ==========================================
                        // FOOTER
                        // ==========================================
                        const AppFooter(),
                      ],
                    ),
                  );
                },
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
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),

            const SizedBox(height: 12),

            const Text(
              'Terjadi Kesalahan',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3E50),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _refreshData,

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
    return Stack(
      clipBehavior: Clip.none,

      children: [
        // ======================================================
        // BACKGROUND SEKOLAH
        // ======================================================
        Container(
          height: 320,
          width: double.infinity,

          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg8.png'),

              fit: BoxFit.cover,

              alignment: Alignment.topCenter,
            ),
          ),
        ),

        // Sapaan seperti Home EcoCash Indonesia, memakai data profil API.
        Positioned(
          top: 62,
          left: 20,
          // Sisakan ruang untuk lonceng notifikasi di kanan, supaya nama panjang
          // tidak tertimpa tombol.
          right: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai, ${_getUserName(data)}!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Siap untuk mendaur ulang?',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
            ],
          ),
        ),

        // ======================================================
        // NOTIFICATION BELL
        // ======================================================
        Positioned(
          top: 54,
          right: 16,
          child: _buildNotificationBell(),
        ),

        // ======================================================
        // BALANCE CARD
        // ======================================================
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,

          child: _buildBalanceCard(context, data),
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
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
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
                color: Color(0xFF212121),
                size: 24,
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
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
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
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(25),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),

            blurRadius: 20,

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
            children: [
              Image.asset(
                'assets/icons/dompet.png',
                height: 45,
                width: 45,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 15),

              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,

                  alignment: Alignment.centerLeft,

                  child: Text(
                    _formatBalance(data['balance']),

                    maxLines: 1,

                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D3E50),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // ====================================================
          // CARBON + POINT
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // =================================================
              // CARBON
              // =================================================
              Expanded(
                child: _buildStatItem(
                  label: 'Karbon Disimpan:',

                  value: '${_formatCarbon(data['carbon'])} kg CO₂e',

                  path: 'assets/icons/daun.png',
                ),
              ),

              const SizedBox(width: 12),

              // =================================================
              // POINT
              // =================================================
              Expanded(
                child: _buildStatItem(
                  label: 'Total Point:',

                  value: '${data['points'] ?? '0'}',

                  path: 'assets/icons/star.png',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          const SizedBox(height: 20),

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
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(12),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Image.asset(path, height: 35, width: 35, fit: BoxFit.contain),

              const SizedBox(height: 8),

              SizedBox(
                height: 28,

                child: Text(
                  label,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A6B7D),
                  ),
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Image.asset(path, height: 35, width: 35, fit: BoxFit.contain),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 2),

              Text(
                value,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E50),
                ),
              ),
            ],
          ),
        ),
      ],
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E50),
            ),
          ),

          const SizedBox(height: 15),

          // ====================================================
          // MENU CONTAINER
          // ====================================================
          Container(
            width: double.infinity,

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(30),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),

                  blurRadius: 20,

                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // ==============================================
                // SESSION HISTORY
                //
                // Sesi yang masih terbuka (sedang menimbang atau
                // menunggu konfirmasi) tampil di bagian atas halaman
                // riwayat, jadi tidak ada lagi menu "Sesi Aktif"
                // terpisah. Badge di sini hanya pengingat.
                // ==============================================
                _buildMenuTile(
                  path: 'assets/icons/riwayat.png',

                  title: 'Riwayat Setor',

                  subtitle: _unconfirmedSessions > 0
                      ? (_unconfirmedSessions == 1
                            ? '1 sesi menunggu konfirmasi'
                            : '$_unconfirmedSessions sesi menunggu konfirmasi')
                      : null,

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

                _buildDivider(),

                // ==============================================
                // PROFILE
                // ==============================================
                _buildMenuTile(
                  path: 'assets/icons/plus.png',

                  title: 'Profil',

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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU TILE
  // ============================================================

  Widget _buildMenuTile({
    required String path,
    required String title,
    VoidCallback? onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),

        leading: Image.asset(path, height: 30, width: 30, fit: BoxFit.contain),

        title: Text(
          title,

          maxLines: 2,

          overflow: TextOverflow.ellipsis,

          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3E50),
          ),
        ),

        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A8A9A),
                ),
              ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            if (trailing != null) ...[trailing, const SizedBox(width: 6)],

            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF5A6B7D),
            ),
          ],
        ),

        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF5F5F5),
      indent: 20,
      endIndent: 20,
    );
  }
}
