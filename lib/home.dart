import 'dart:convert';

import 'package:ecocash_sekolah/bantuan/bantuan.dart';
import 'package:ecocash_sekolah/ecomer/ecomer.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/maps/maps.dart';
import 'package:ecocash_sekolah/profile/profile.dart';
import 'package:ecocash_sekolah/refund/refund.dart';
import 'package:ecocash_sekolah/saldo/saldo.dart';
import 'package:ecocash_sekolah/setor_sampah/scan.dart';
import 'package:ecocash_sekolah/transfer/transfer.dart';
import 'package:ecocash_sekolah/app_footer.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      throw Exception(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }

    debugPrint('');
    debugPrint('==============================================');
    debugPrint('HOME ECOCASH SEKOLAH');
    debugPrint('BASE URL : ${ApiConfig.baseUrl}');
    debugPrint('HAS TOKEN: ${ApiConfig.hasToken}');
    debugPrint('==============================================');
    debugPrint('');

    // ==========================================================
    // REQUEST BERSAMAAN
    // ==========================================================

    /*
     * Sama dengan EcoCash Indonesia.
     *
     * Profile, wallet dan carbon diambil secara bersamaan
     * supaya Home tidak melakukan request satu per satu.
     */

    final List<http.Response> responses =
        await Future.wait<http.Response>([
      // PROFILE
      http.get(
        Uri.parse(ApiConfig.getUserProfile),
        headers: ApiConfig.headers,
      ),

      // WALLET
      http.get(
        Uri.parse(ApiConfig.getMyWallet),
        headers: ApiConfig.headers,
      ),

      // CARBON
      http.get(
        Uri.parse(ApiConfig.getMyCarbon),
        headers: ApiConfig.headers,
      ),
    ]);

    final http.Response profileResponse = responses[0];
    final http.Response walletResponse = responses[1];
    final http.Response carbonResponse = responses[2];

    // ==========================================================
    // DEBUG RESPONSE
    // ==========================================================

    debugPrint('');
    debugPrint('========== HOME API RESPONSE ==========');

    debugPrint(
      'PROFILE STATUS : ${profileResponse.statusCode}',
    );

    debugPrint(
      'WALLET STATUS  : ${walletResponse.statusCode}',
    );

    debugPrint(
      'CARBON STATUS  : ${carbonResponse.statusCode}',
    );

    debugPrint('=======================================');
    debugPrint('');

    // ==========================================================
    // AUTH ERROR
    // ==========================================================

    /*
     * Jika token sudah tidak berlaku,
     * hapus token agar request selanjutnya tidak memakai
     * JWT yang sudah invalid.
     */

    if (profileResponse.statusCode == 401 ||
        walletResponse.statusCode == 401 ||
        carbonResponse.statusCode == 401) {
      ApiConfig.clearToken();

      throw Exception(
        'Sesi login sudah berakhir. Silakan login kembali.',
      );
    }

    if (profileResponse.statusCode == 403 ||
        walletResponse.statusCode == 403 ||
        carbonResponse.statusCode == 403) {
      throw Exception(
        'Akun tidak memiliki akses ke data EcoCash.',
      );
    }

    // ==========================================================
    // CHECK PROFILE
    // ==========================================================

    if (profileResponse.statusCode != 200) {
      throw Exception(
        'Gagal memuat profil '
        '(${profileResponse.statusCode})',
      );
    }

    // ==========================================================
    // CHECK WALLET
    // ==========================================================

    if (walletResponse.statusCode != 200) {
      throw Exception(
        'Gagal memuat dompet '
        '(${walletResponse.statusCode})',
      );
    }

    // ==========================================================
    // CHECK CARBON
    // ==========================================================

    if (carbonResponse.statusCode != 200) {
      throw Exception(
        'Gagal memuat carbon '
        '(${carbonResponse.statusCode})',
      );
    }

    // ==========================================================
    // DECODE JSON
    // ==========================================================

    dynamic decodedProfile;
    dynamic decodedWallet;
    dynamic decodedCarbon;

    try {
      decodedProfile = jsonDecode(
        profileResponse.body,
      );

      decodedWallet = jsonDecode(
        walletResponse.body,
      );

      decodedCarbon = jsonDecode(
        carbonResponse.body,
      );
    } catch (error) {
      debugPrint(
        'HOME JSON DECODE ERROR: $error',
      );

      throw Exception(
        'Response server tidak valid.',
      );
    }

    // ==========================================================
    // EXTRACT DATA
    // ==========================================================

    final Map<String, dynamic> profileData =
        _extractDataMap(decodedProfile);

    final Map<String, dynamic> walletData =
        _extractDataMap(decodedWallet);

    final Map<String, dynamic> carbonData =
        _extractDataMap(decodedCarbon);

    // ==========================================================
    // DEBUG DATA
    // ==========================================================

    debugPrint('');
    debugPrint('==============================================');

    debugPrint(
      'PROFILE DATA : $profileData',
    );

    debugPrint(
      'WALLET DATA  : $walletData',
    );

    debugPrint(
      'CARBON DATA  : $carbonData',
    );

    debugPrint('==============================================');
    debugPrint('');

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

      'carbon':
          carbonData['totalSavedKg'] ??
          carbonData['carbon'] ??
          0,

      'carbonUnit':
          carbonData['unit'] ??
          'kg CO2e',

      'carbonChange':
          carbonData['changePercent'] ??
          0,

      'totalWasteKg':
          carbonData['totalWasteKg'] ??
          0,

      'carbonTransactions':
          carbonData['transactions'] ??
          0,

      'carbonTrend':
          carbonData['trend'] ??
          [],
    };
  }

  // ============================================================
  // EXTRACT API DATA
  // ============================================================

  Map<String, dynamic> _extractDataMap(
    dynamic responseData,
  ) {
    if (responseData is! Map) {
      return {};
    }

    final Map<String, dynamic> responseMap =
        Map<String, dynamic>.from(
      responseData,
    );

    final dynamic data =
        responseMap['data'];

    /*
     * Format backend:
     *
     * {
     *   "message": "...",
     *   "data": {
     *      ...
     *   }
     * }
     */

    if (data is Map) {
      return Map<String, dynamic>.from(
        data,
      );
    }

    /*
     * Kalau endpoint langsung mengembalikan object,
     * tetap bisa diproses.
     */

    return responseMap;
  }

  // ============================================================
  // REFRESH DATA
  // ============================================================

  Future<void> _refreshData() async {
    debugPrint('');
    debugPrint('REFRESH HOME ECOCASH SEKOLAH');
    debugPrint('');

    final Future<Map<String, dynamic>> newFuture =
        _fetchUserData();

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

  // ============================================================
  // FORMAT CARBON
  // ============================================================

  String _formatCarbon(
    dynamic value,
  ) {
    if (value == null) {
      return '0';
    }

    final double number =
        double.tryParse(
          value.toString(),
        ) ??
        0;

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

  String _formatBalance(
    dynamic value,
  ) {
    if (value == null) {
      return 'Rp0';
    }

    final double number =
        double.tryParse(
          value.toString(),
        ) ??
        0;

    final int integerValue =
        number.toInt();

    final String formatted =
        integerValue
            .toString()
            .replaceAllMapped(
              RegExp(
                r'(\d{1,3})(?=(\d{3})+(?!\d))',
              ),
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.white,

      body: SafeArea(
        top: false,

        // ======================================================
        // PULL TO REFRESH
        // ======================================================

        child: RefreshIndicator(
          onRefresh:
              _refreshData,

          child:
              FutureBuilder<
                Map<String, dynamic>
              >(
            future:
                _userDataFuture,

            builder: (
              BuildContext context,
              AsyncSnapshot<
                Map<String, dynamic>
              > snapshot,
            ) {
              // ================================================
              // LOADING
              // ================================================

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              // ================================================
              // ERROR
              // ================================================

              if (snapshot.hasError) {
                return SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  child: SizedBox(
                    height:
                        MediaQuery.sizeOf(
                          context,
                        ).height,

                    child:
                        _buildErrorView(
                      context,
                      snapshot.error
                          .toString(),
                    ),
                  ),
                );
              }

              // ================================================
              // NO DATA
              // ================================================

              if (!snapshot.hasData) {
                return SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  child: SizedBox(
                    height:
                        MediaQuery.sizeOf(
                          context,
                        ).height,

                    child:
                        _buildErrorView(
                      context,
                      'Data pengguna tidak tersedia',
                    ),
                  ),
                );
              }

              // ================================================
              // SUCCESS DATA
              // ================================================

              final Map<String, dynamic>
                  data =
                  snapshot.data ?? {};

              return SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                child: Column(
                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    SizedBox(
                      height: 450,

                      child:
                          _buildHeader(
                        context,
                        data,
                      ),
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    // ==========================================
                    // MENU
                    // ==========================================

                    _buildCombinedPaymentMenu(
                      context,
                    ),

                    const SizedBox(
                      height: 50,
                    ),

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

  Widget _buildErrorView(
    BuildContext context,
    String message,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
              color:
                  Colors.redAccent,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Terjadi Kesalahan',

              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF2D3E50),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                fontSize: 13,
                color:
                    Colors.grey,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
                  _refreshData,

              icon:
                  const Icon(
                Icons.refresh,
              ),

              label:
                  const Text(
                'Coba Lagi',
              ),
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

  Widget _buildHeader(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Stack(
      clipBehavior:
          Clip.none,

      children: [
        // ======================================================
        // BACKGROUND SEKOLAH
        // ======================================================

        Container(
          height: 320,
          width:
              double.infinity,

          decoration:
              const BoxDecoration(
            image:
                DecorationImage(
              image:
                  AssetImage(
                'assets/bg8.png',
              ),

              fit:
                  BoxFit.cover,

              alignment:
                  Alignment.topCenter,
            ),
          ),
        ),

        // ======================================================
        // BALANCE CARD
        // ======================================================

        Positioned(
          bottom: 0,
          left: 20,
          right: 20,

          child:
              _buildBalanceCard(
            context,
            data,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 25,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          25,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.05,
            ),

            blurRadius:
                20,

            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),

      child: Column(
        mainAxisSize:
            MainAxisSize.min,

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
                fit:
                    BoxFit.contain,
              ),

              const SizedBox(
                width: 15,
              ),

              Expanded(
                child:
                    FittedBox(
                  fit:
                      BoxFit.scaleDown,

                  alignment:
                      Alignment.centerLeft,

                  child: Text(
                    _formatBalance(
                      data['balance'],
                    ),

                    maxLines: 1,

                    style:
                        const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w900,
                      color:
                          Color(
                        0xFF2D3E50,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 25,
          ),

          // ====================================================
          // CARBON + POINT
          // ====================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // =================================================
              // CARBON
              // =================================================

              Expanded(
                child:
                    _buildStatItem(
                  label:
                      'Carbon Saved:',

                  value:
                      '${_formatCarbon(data['carbon'])} Kg CO₂',

                  path:
                      'assets/icons/daun.png',
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              // =================================================
              // POINT
              // =================================================

              Expanded(
                child:
                    _buildStatItem(
                  label:
                      'Total Point:',

                  value:
                      '${data['points'] ?? '0'}',

                  path:
                      'assets/icons/star.png',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color:
                Color(
              0xFFF0F0F0,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ====================================================
          // ACTION MENU
          // ====================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // =================================================
              // SCAN BARCODE
              // =================================================

              Expanded(
                child:
                    _buildActionItem(
                  path:
                      'assets/icons/scan.png',

                  label:
                      'Scan Barcode',

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (
                          BuildContext context,
                        ) {
                          return const ScanPage();
                        },
                      ),
                    ).then(
                      (_) {
                        /*
                         * Setelah setor sampah selesai,
                         * saldo, point dan carbon diperbarui.
                         */
                        _refreshData();
                      },
                    );
                  },
                ),
              ),

              // =================================================
              // TOP UP
              // =================================================

              Expanded(
                child:
                    _buildActionItem(
                  path:
                      'assets/icons/topup.png',

                  label:
                      'Top Up',

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (
                          BuildContext context,
                        ) {
                          return const IsiSaldoPage();
                        },
                      ),
                    ).then(
                      (_) {
                        _refreshData();
                      },
                    );
                  },
                ),
              ),

              // =================================================
              // TRANSFER
              // =================================================

              Expanded(
                child:
                    _buildActionItem(
                  path:
                      'assets/icons/panah.png',

                  label:
                      'Transfer',

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (
                          BuildContext context,
                        ) {
                          return const TransferPage();
                        },
                      ),
                    ).then(
                      (_) {
                        _refreshData();
                      },
                    );
                  },
                ),
              ),

              // =================================================
              // HISTORY
              // =================================================

              Expanded(
                child:
                    _buildActionItem(
                  path:
                      'assets/icons/lock.png',

                  label:
                      'History',

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (
                          BuildContext context,
                        ) {
                          return const RefundsScreen();
                        },
                      ),
                    ).then(
                      (_) {
                        _refreshData();
                      },
                    );
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
      color:
          Colors.transparent,

      child: InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 5,
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Image.asset(
                path,
                height: 35,
                width: 35,
                fit:
                    BoxFit.contain,
              ),

              const SizedBox(
                height: 8,
              ),

              SizedBox(
                height: 28,

                child: Text(
                  label,

                  maxLines: 2,

                  overflow:
                      TextOverflow.ellipsis,

                  textAlign:
                      TextAlign.center,

                  style:
                      const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(
                      0xFF5A6B7D,
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
  // STAT ITEM
  // ============================================================

  Widget _buildStatItem({
    required String label,
    required String value,
    required String path,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,

      children: [
        Image.asset(
          path,
          height: 35,
          width: 35,
          fit:
              BoxFit.contain,
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                label,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Colors.grey,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                value,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(
                    0xFF2D3E50,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIVE PAYMENT MENU
  // ============================================================

  Widget _buildCombinedPaymentMenu(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ====================================================
          // TITLE
          // ====================================================

          const Text(
            'Your active payment',

            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(
                0xFF2D3E50,
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          // ====================================================
          // PAYMENT CONTAINER
          // ====================================================

          Container(
            width:
                double.infinity,

            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(
                    0xFFFF7066,
                  ),
                  Color(
                    0xFFFF8A84,
                  ),
                ],
              ),

              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                // ==============================================
                // DIGITAL VOUCHER
                // ==============================================

                Padding(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .confirmation_number,

                        color:
                            Colors.white,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      const Expanded(
                        child: Text(
                          'Digital Voucher',

                          maxLines: 1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              TextStyle(
                            color:
                                Colors.white,

                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      ElevatedButton(
                        /*
                         * Tampilan dan fungsi tombol Sekolah
                         * dipertahankan seperti sebelumnya.
                         *
                         * Jika VoucherPage Sekolah sudah dibuat,
                         * nanti dapat dihubungkan ke endpoint
                         * getAvailableVouchers.
                         */
                        onPressed: () {},

                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.white
                                  .withOpacity(
                            0.30,
                          ),

                          foregroundColor:
                              Colors.white,

                          elevation: 0,

                          minimumSize:
                              const Size(
                            0,
                            36,
                          ),

                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                16,

                            vertical:
                                8,
                          ),

                          shape:
                              const StadiumBorder(),
                        ),

                        child:
                            const Text(
                          'Pakai',

                          style:
                              TextStyle(
                            color:
                                Colors.white,

                            fontSize:
                                12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // WHITE MENU
                // ==============================================

                Container(
                  width:
                      double.infinity,

                  decoration:
                      const BoxDecoration(
                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.all(
                      Radius.circular(
                        30,
                      ),
                    ),
                  ),

                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      // =========================================
                      // NEAREST RETURN POINT
                      // =========================================

                      _buildMenuTile(
                        path:
                            'assets/icons/lokasi.png',

                        title:
                            'Find nearest return point',

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (
                                BuildContext context,
                              ) {
                                return const MapsPage();
                              },
                            ),
                          ).then(
                            (_) {
                              _refreshData();
                            },
                          );
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // MARKETPLACE
                      // =========================================

                      _buildMenuTile(
                        path:
                            'assets/icons/panahb.png',

                        title:
                            'Exchange balance for goods',

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (
                                BuildContext context,
                              ) {
                                return const EcomerPage();
                              },
                            ),
                          ).then(
                            (_) {
                              /*
                               * Saldo bisa berubah setelah
                               * melakukan pembelian.
                               */
                              _refreshData();
                            },
                          );
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // CHARITY
                      // =========================================

                      _buildMenuTile(
                        path:
                            'assets/icons/love.png',

                        title:
                            'Charities',

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (
                                BuildContext context,
                              ) {
                                return const BantuanPage();
                              },
                            ),
                          ).then(
                            (_) {
                              /*
                               * Saldo bisa berubah setelah
                               * melakukan donasi.
                               */
                              _refreshData();
                            },
                          );
                        },
                      ),

                      _buildDivider(),

                      // =========================================
                      // OTHER / PROFILE
                      // =========================================

                      _buildMenuTile(
                        path:
                            'assets/icons/plus.png',

                        title:
                            'Other',

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (
                                BuildContext context,
                              ) {
                                return const ProfilePage();
                              },
                            ),
                          ).then(
                            (_) {
                              /*
                               * Profile bisa berubah.
                               */
                              _refreshData();
                            },
                          );
                        },
                      ),
                    ],
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
  // MENU TILE
  // ============================================================

  Widget _buildMenuTile({
    required String path,
    required String title,
    VoidCallback? onTap,
  }) {
    return Material(
      color:
          Colors.transparent,

      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 2,
        ),

        leading:
            Image.asset(
          path,
          height: 30,
          width: 30,
          fit:
              BoxFit.contain,
        ),

        title:
            Text(
          title,

          maxLines: 2,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
            color:
                Color(
              0xFF2D3E50,
            ),
          ),
        ),

        trailing:
            const Icon(
          Icons.chevron_right,
          size: 18,
          color:
              Color(
            0xFF5A6B7D,
          ),
        ),

        onTap:
            onTap,
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
      color:
          Color(
        0xFFF5F5F5,
      ),
      indent: 20,
      endIndent: 20,
    );
  }
}