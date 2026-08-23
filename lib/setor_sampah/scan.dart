import 'dart:async';
import 'dart:convert';

import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/konfirmasi.dart';
import 'package:ecocash_sekolah/app_footer.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // ============================================================
  // QR PERMANEN
  // ============================================================

  String? _qrIdentifier;

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // MACHINE SESSION
  // ============================================================

  Timer? _pollingTimer;

  bool _isCheckingSession = false;
  bool _baselineReady = false;
  bool _hasNavigated = false;

  final Set<String> _knownSessionIds = <String>{};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializePage();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializePage() async {
    debugPrint('');
    debugPrint('======================================');
    debugPrint('SCAN PAGE ECOCASH SEKOLAH');
    debugPrint('BASE URL : ${ApiConfig.baseUrl}');
    debugPrint('======================================');
    debugPrint('');

    /*
     * Sama dengan EcoCash Indonesia.
     *
     * Pertama kita ambil session yang sudah ada.
     *
     * Tujuannya supaya session lama tidak dianggap
     * sebagai hasil scan QR yang baru.
     */
    await _prepareSessionBaseline();

    if (!mounted) {
      return;
    }

    /*
     * Setelah baseline siap,
     * ambil QR permanen user.
     */
    await _fetchQrCredential();
  }

  // ============================================================
  // GET PERMANENT QR
  // ============================================================

  Future<void> _fetchQrCredential() async {
    if (!mounted || _hasNavigated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('');
      debugPrint('======================================');
      debugPrint('GET PERMANENT QR');
      debugPrint('URL: ${ApiConfig.getMyCredentialQr}');
      debugPrint('======================================');

      final response = await http.get(
        Uri.parse(ApiConfig.getMyCredentialQr),
        headers: ApiConfig.headers,
      );

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: ${response.body}');

      if (!mounted || _hasNavigated) {
        return;
      }

      // ========================================================
      // 401
      // ========================================================

      if (response.statusCode == 401) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Sesi login tidak valid. Silakan login kembali.';
        });

        return;
      }

      // ========================================================
      // 403
      // ========================================================

      if (response.statusCode == 403) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Anda tidak memiliki akses untuk mengambil QR.';
        });

        return;
      }

      // ========================================================
      // 404
      // ========================================================

      if (response.statusCode == 404) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Endpoint QR permanen tidak ditemukan.';
        });

        return;
      }

      // ========================================================
      // SERVER ERROR
      // ========================================================

      if (response.statusCode >= 500) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Server gagal mengambil QR EcoCash.';
        });

        return;
      }

      // ========================================================
      // STATUS SELAIN 200
      // ========================================================

      if (response.statusCode != 200) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Gagal memuat QR (${response.statusCode}).';
        });

        return;
      }

      // ========================================================
      // PARSE RESPONSE
      // ========================================================

      final dynamic body = jsonDecode(response.body);

      if (body is! Map) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Format data QR tidak sesuai.';
        });

        return;
      }

      final dynamic data = body['data'];

      if (data == null || data is! Map) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Data credential QR tidak ditemukan.';
        });

        return;
      }

      // ========================================================
      // IDENTIFIER
      // ========================================================

      /*
       * PENTING:
       *
       * QR EcoCash Indonesia hanya berisi:
       *
       * credential.identifier
       *
       * Bukan:
       *
       * - JWT
       * - userId
       * - credentialId
       * - JSON
       * - access token sementara
       */

      final String? identifier =
          data['identifier']?.toString().trim();

      debugPrint('');
      debugPrint('QR IDENTIFIER: $identifier');
      debugPrint('');

      if (identifier == null || identifier.isEmpty) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Identifier QR tidak ditemukan.';
        });

        return;
      }

      // ========================================================
      // CHECK ACTIVE
      // ========================================================

      final bool isActive = data['isActive'] == true;

      if (!isActive) {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'QR EcoCash sedang tidak aktif.';
        });

        return;
      }

      // ========================================================
      // CHECK TYPE
      // ========================================================

      final String type =
          data['type']?.toString().toUpperCase() ?? '';

      if (type != 'QR') {
        setState(() {
          _qrIdentifier = null;
          _isLoading = false;
          _errorMessage =
              'Credential yang diterima bukan QR.';
        });

        return;
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      setState(() {
        _qrIdentifier = identifier;
        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint('');
      debugPrint('======================================');
      debugPrint('QR PERMANEN BERHASIL DIMUAT');
      debugPrint('IDENTIFIER: $_qrIdentifier');
      debugPrint('======================================');
      debugPrint('');

      /*
       * Setelah QR tampil,
       * mulai cek apakah mesin sudah membuat session baru.
       */
      _startSessionPolling();
    } catch (error, stackTrace) {
      debugPrint('');
      debugPrint('QR REQUEST ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('');

      if (!mounted || _hasNavigated) {
        return;
      }

      setState(() {
        _qrIdentifier = null;
        _isLoading = false;
        _errorMessage =
            'Tidak dapat terhubung ke server EcoCash.';
      });
    }
  }

  // ============================================================
  // SESSION BASELINE
  // ============================================================

  Future<void> _prepareSessionBaseline() async {
    try {
      debugPrint('');
      debugPrint('======================================');
      debugPrint('PREPARE SESSION BASELINE');
      debugPrint('URL: ${ApiConfig.getMySessionHistory}');
      debugPrint('======================================');

      final response = await http.get(
        Uri.parse(ApiConfig.getMySessionHistory),
        headers: ApiConfig.headers,
      );

      debugPrint(
        'SESSION BASELINE STATUS: ${response.statusCode}',
      );

      debugPrint(
        'SESSION BASELINE BODY: ${response.body}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          'SESSION BASELINE GAGAL: ${response.body}',
        );

        return;
      }

      final dynamic body = jsonDecode(response.body);

      final List<dynamic> sessions =
          _extractSessions(body);

      /*
       * Reset session lama.
       */
      _knownSessionIds.clear();

      for (final dynamic session in sessions) {
        final String? id = _getSessionId(session);

        if (id != null) {
          _knownSessionIds.add(id);
        }
      }

      _baselineReady = true;

      debugPrint('');
      debugPrint('======================================');
      debugPrint(
        'SESSION BASELINE READY',
      );
      debugPrint(
        'TOTAL SESSION LAMA: ${_knownSessionIds.length}',
      );
      debugPrint('======================================');
      debugPrint('');
    } catch (error, stackTrace) {
      debugPrint('');
      debugPrint(
        'SESSION BASELINE ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint('');
    }
  }

  // ============================================================
  // START SESSION POLLING
  // ============================================================

  void _startSessionPolling() {
    /*
     * Jangan ada dua timer polling.
     */
    _pollingTimer?.cancel();

    debugPrint('');
    debugPrint('======================================');
    debugPrint('START POLLING MACHINE SESSION');
    debugPrint('INTERVAL: 2 DETIK');
    debugPrint('======================================');
    debugPrint('');

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted || _hasNavigated) {
          return;
        }

        _checkForNewMachineSession();
      },
    );
  }

  // ============================================================
  // CHECK MACHINE SESSION
  // ============================================================

  Future<void> _checkForNewMachineSession({
    bool showMessageIfNotFound = false,
  }) async {
    /*
     * Hindari request bertumpuk.
     */
    if (!mounted ||
        _hasNavigated ||
        _isCheckingSession) {
      return;
    }

    _isCheckingSession = true;

    if (showMessageIfNotFound && mounted) {
      setState(() {});
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMySessionHistory),
        headers: ApiConfig.headers,
      );

      // ========================================================
      // REQUEST GAGAL
      // ========================================================

      if (response.statusCode != 200) {
        debugPrint(
          'POLLING SESSION ERROR '
          '${response.statusCode}: '
          '${response.body}',
        );

        if (showMessageIfNotFound && mounted) {
          _showSnackBar(
            'Gagal memeriksa status mesin.',
            Colors.red,
          );
        }

        return;
      }

      // ========================================================
      // PARSE RESPONSE
      // ========================================================

      final dynamic body =
          jsonDecode(response.body);

      final List<dynamic> sessions =
          _extractSessions(body);

      // ========================================================
      // BASELINE BELUM SIAP
      // ========================================================

      /*
       * Kalau request baseline saat halaman pertama kali dibuka
       * gagal, polling pertama akan dijadikan baseline.
       *
       * Hal ini penting agar session lama tidak dianggap
       * sebagai session scan baru.
       */

      if (!_baselineReady) {
        for (final dynamic session in sessions) {
          final String? id =
              _getSessionId(session);

          if (id != null) {
            _knownSessionIds.add(id);
          }
        }

        _baselineReady = true;

        debugPrint(
          'BASELINE DIBUAT DARI POLLING PERTAMA',
        );

        if (showMessageIfNotFound && mounted) {
          _showSnackBar(
            'Mesin belum memindai QR. '
            'Arahkan QR ke scanner mesin.',
            Colors.orange,
          );
        }

        return;
      }

      // ========================================================
      // CARI SESSION BARU
      // ========================================================

      final List<Map<String, dynamic>>
          newSessions = [];

      for (final dynamic item in sessions) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> session =
            Map<String, dynamic>.from(item);

        final String? sessionId =
            _getSessionId(session);

        if (sessionId == null) {
          continue;
        }

        /*
         * Kalau id belum pernah ada dalam baseline / polling lama,
         * berarti ini adalah session baru.
         */
        if (!_knownSessionIds.contains(sessionId)) {
          newSessions.add(session);
        }
      }

      // ========================================================
      // UPDATE KNOWN SESSION
      // ========================================================

      /*
       * Setelah dibandingkan,
       * simpan seluruh session yang sekarang ada.
       */

      for (final dynamic session in sessions) {
        final String? id =
            _getSessionId(session);

        if (id != null) {
          _knownSessionIds.add(id);
        }
      }

      // ========================================================
      // TIDAK ADA SESSION BARU
      // ========================================================

      if (newSessions.isEmpty) {
        if (showMessageIfNotFound && mounted) {
          _showSnackBar(
            'Mesin belum memindai QR. '
            'Arahkan QR ke scanner mesin.',
            Colors.orange,
          );
        }

        return;
      }

      // ========================================================
      // FILTER SESSION AKTIF
      // ========================================================

      final List<Map<String, dynamic>>
          usableSessions = newSessions.where(
        (Map<String, dynamic> session) {
          return _isUsableSession(session);
        },
      ).toList();

      /*
       * Kalau seluruh session baru ternyata sudah terminal,
       * jangan masuk ke halaman konfirmasi.
       */
      if (usableSessions.isEmpty) {
        return;
      }

      // ========================================================
      // SORT SESSION TERBARU
      // ========================================================

      usableSessions.sort(
        (
          Map<String, dynamic> a,
          Map<String, dynamic> b,
        ) {
          final int idA =
              _parseSessionId(
                a['id'] ?? a['sessionId'],
              ) ??
              0;

          final int idB =
              _parseSessionId(
                b['id'] ?? b['sessionId'],
              ) ??
              0;

          /*
           * Terbesar / terbaru di atas.
           */
          return idB.compareTo(idA);
        },
      );

      // ========================================================
      // AMBIL SESSION TERBARU
      // ========================================================

      final Map<String, dynamic>
          newestSession =
          usableSessions.first;

      final int? sessionId =
          _parseSessionId(
        newestSession['id'] ??
            newestSession['sessionId'],
      );

      if (sessionId == null) {
        debugPrint(
          'SESSION BARU DITEMUKAN '
          'TETAPI SESSION ID INVALID',
        );

        return;
      }

      final String status =
          newestSession['status']
                  ?.toString()
                  .toUpperCase() ??
              '';

      debugPrint('');
      debugPrint('======================================');
      debugPrint('MESIN BERHASIL MEMINDAI QR');
      debugPrint('SESSION ID : $sessionId');
      debugPrint('STATUS     : $status');
      debugPrint('======================================');
      debugPrint('');

      // ========================================================
      // NAVIGATION
      // ========================================================

      _openConfirmationPage(sessionId);
    } catch (error, stackTrace) {
      debugPrint('');
      debugPrint(
        'CHECK SESSION ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint('');

      if (showMessageIfNotFound && mounted) {
        _showSnackBar(
          'Terjadi kesalahan saat memeriksa mesin.',
          Colors.red,
        );
      }
    } finally {
      _isCheckingSession = false;

      if (showMessageIfNotFound &&
          mounted &&
          !_hasNavigated) {
        setState(() {});
      }
    }
  }

  // ============================================================
  // EXTRACT SESSION LIST
  // ============================================================

  List<dynamic> _extractSessions(
    dynamic responseBody,
  ) {
    if (responseBody == null) {
      return [];
    }

    // ==========================================================
    // RESPONSE LANGSUNG LIST
    // ==========================================================

    if (responseBody is List) {
      return responseBody;
    }

    if (responseBody is! Map) {
      return [];
    }

    // ==========================================================
    // DATA
    // ==========================================================

    final dynamic data =
        responseBody['data'];

    /*
     * Contoh:
     *
     * {
     *   "data": [...]
     * }
     */

    if (data is List) {
      return data;
    }

    /*
     * Beberapa kemungkinan backend pagination:
     *
     * {
     *   "data": {
     *     "sessions": [...]
     *   }
     * }
     *
     * atau:
     *
     * {
     *   "data": {
     *     "items": [...]
     *   }
     * }
     */

    if (data is Map) {
      final List<dynamic> possibilities = [
        data['sessions'],
        data['items'],
        data['rows'],
        data['results'],
        data['data'],
      ];

      for (final dynamic value
          in possibilities) {
        if (value is List) {
          return value;
        }
      }
    }

    // ==========================================================
    // ROOT COLLECTION
    // ==========================================================

    final List<dynamic> possibilities = [
      responseBody['sessions'],
      responseBody['items'],
      responseBody['rows'],
      responseBody['results'],
    ];

    for (final dynamic value
        in possibilities) {
      if (value is List) {
        return value;
      }
    }

    return [];
  }

  // ============================================================
  // GET SESSION ID
  // ============================================================

  String? _getSessionId(
    dynamic session,
  ) {
    if (session is! Map) {
      return null;
    }

    final dynamic id =
        session['id'] ??
            session['sessionId'];

    if (id == null) {
      return null;
    }

    final String value =
        id.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  // ============================================================
  // PARSE SESSION ID
  // ============================================================

  int? _parseSessionId(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // SESSION STATUS
  // ============================================================

  bool _isUsableSession(
    Map<String, dynamic> session,
  ) {
    final String status =
        session['status']
                ?.toString()
                .toUpperCase() ??
            '';

    /*
     * Session dengan status berikut
     * tidak boleh digunakan.
     */
    const Set<String> terminalStatuses = {
      'COMPLETED',
      'COMPLETE',
      'CANCELLED',
      'CANCELED',
      'EXPIRED',
      'FAILED',
      'REJECTED',
    };

    return !terminalStatuses.contains(
      status,
    );
  }

  // ============================================================
  // MANUAL CHECK
  // ============================================================

  Future<void> _manualCheck() async {
    if (_isLoading ||
        _qrIdentifier == null ||
        _qrIdentifier!.isEmpty ||
        _hasNavigated) {
      return;
    }

    await _checkForNewMachineSession(
      showMessageIfNotFound: true,
    );
  }

  // ============================================================
  // OPEN CONFIRMATION
  // ============================================================

  void _openConfirmationPage(
    int sessionId,
  ) {
    if (!mounted || _hasNavigated) {
      return;
    }

    /*
     * Mencegah navigation dilakukan dua kali
     * karena polling berjalan setiap 2 detik.
     */
    _hasNavigated = true;

    /*
     * Stop polling.
     */
    _pollingTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (
          BuildContext context,
        ) {
          return SetorSampahScreen(
            sessionId: sessionId,
          );
        },
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message,
    Color backgroundColor,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              backgroundColor,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
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
          const Color(0xFFF5F5F5),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    constraints.maxHeight,
              ),
              child: Column(
                children: [
                  _buildHeader(context),

                  const SizedBox(
                    height: 20,
                  ),

                  const AppFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER + CARD
  // ============================================================

  Widget _buildHeader(
    BuildContext context,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ======================================================
        // BACKGROUND HEADER
        // ======================================================

        Container(
          height: 280,
          width: double.infinity,
          padding:
              const EdgeInsets.only(
            top: 60,
            left: 20,
            right: 20,
          ),
          decoration:
              const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/bg3.png',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // BACK BUTTON
              // ==================================================

              GestureDetector(
                onTap: () {
                  /*
                   * Stop polling kalau user kembali.
                   */
                  _pollingTimer?.cancel();

                  Navigator.pop(
                    context,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.all(
                    8,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(
                      0.30,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              // ==================================================
              // TITLE
              // ==================================================

              const Expanded(
                child: Text(
                  'Setor Sampah',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // MAIN CARD
        // ======================================================

        Container(
          width: double.infinity,
          margin:
              const EdgeInsets.only(
            top: 130,
            left: 20,
            right: 20,
            bottom: 30,
          ),
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              25,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(
                  0.05,
                ),
                blurRadius: 15,
                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Tunjukkan Kode QR',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF2D3E50),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              const Text(
                'Arahkan kode QR ini ke scanner mesin.\n'
                'Sistem akan mendeteksi identitas dan\n'
                'memulai sesi transaksi Anda.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 35,
              ),

              // ==================================================
              // QR
              // ==================================================

              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final double
                      qrContainerSize =
                      constraints.maxWidth <
                              230
                          ? constraints
                              .maxWidth
                          : 220;

                  final double frameSize =
                      constraints.maxWidth <
                              240
                          ? constraints
                              .maxWidth
                          : 230;

                  final double qrSize =
                      qrContainerSize -
                          40;

                  return Stack(
                    alignment:
                        Alignment.center,
                    children: [
                      Container(
                        width:
                            qrContainerSize,
                        height:
                            qrContainerSize,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          border:
                              Border.all(
                            color: Colors
                                .grey
                                .shade300,
                            width: 2,
                          ),
                        ),
                        child:
                            ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                          child:
                              _buildQrContent(
                            qrSize,
                          ),
                        ),
                      ),

                      IgnorePointer(
                        child:
                            CustomBarcodeFrame(
                          size:
                              frameSize,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // QR STATUS
              // ==================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons
                        .timer_outlined,
                    size: 16,
                    color: Colors.orange
                        .shade700,
                  ),

                  const SizedBox(
                    width: 5,
                  ),

                  Flexible(
                    child: Text(
                      _isLoading
                          ? 'Memuat QR EcoCash'
                          : _qrIdentifier !=
                                  null
                              ? 'QR EcoCash Permanen'
                              : 'QR tidak tersedia',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        color: Colors
                            .orange
                            .shade700,
                        fontWeight:
                            FontWeight
                                .bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // REFRESH QR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _isLoading
                          ? null
                          : _fetchQrCredential,
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Refresh Kode',
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        Colors.green,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                    side:
                        const BorderSide(
                      color:
                          Colors.green,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // MANUAL CHECK
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton(
                  onPressed:
                      (_isLoading ||
                              _qrIdentifier ==
                                  null ||
                              _isCheckingSession)
                          ? null
                          : _manualCheck,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.green,
                    disabledBackgroundColor:
                        Colors.grey
                            .shade400,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      _isCheckingSession
                          ? const SizedBox(
                              width: 20,
                              height:
                                  20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color: Colors
                                    .white,
                              ),
                            )
                          : const Text(
                              'Lanjut ke Konfirmasi',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // INFO
              // ==================================================

              const Text(
                'Halaman akan berpindah otomatis setelah QR dipindai mesin.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QR CONTENT
  // ============================================================

  Widget _buildQrContent(
    double qrSize,
  ) {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (_qrIdentifier == null ||
        _qrIdentifier!.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 30,
                color:
                    Colors.red.shade400,
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                _errorMessage ??
                    'Gagal memuat QR',
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================================
    // QR SUCCESS
    // ==========================================================

    /*
     * QR hanya berisi credential identifier.
     *
     * Mesin akan membaca identifier ini
     * kemudian backend resolve user berdasarkan:
     *
     * resolveByIdentifier(identifier)
     */

    return Center(
      child: QrImageView(
        data: _qrIdentifier!,
        version:
            QrVersions.auto,
        size: qrSize,
        padding:
            const EdgeInsets.all(
          8,
        ),
        backgroundColor:
            Colors.white,
      ),
    );
  }
}

// ============================================================
// CUSTOM QR FRAME
// ============================================================

class CustomBarcodeFrame
    extends StatelessWidget {
  final double size;

  const CustomBarcodeFrame({
    super.key,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter:
            BarcodeFramePainter(),
      ),
    );
  }
}

// ============================================================
// QR FRAME PAINTER
// ============================================================

class BarcodeFramePainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint paint =
        Paint()
          ..color =
              const Color(
            0xFF4CAF50,
          )
          ..strokeWidth = 6
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    const double cornerSize =
        40;

    // ==========================================================
    // LEFT TOP
    // ==========================================================

    canvas.drawPath(
      Path()
        ..moveTo(
          0,
          cornerSize,
        )
        ..lineTo(
          0,
          0,
        )
        ..lineTo(
          cornerSize,
          0,
        ),
      paint,
    );

    // ==========================================================
    // RIGHT TOP
    // ==========================================================

    canvas.drawPath(
      Path()
        ..moveTo(
          size.width -
              cornerSize,
          0,
        )
        ..lineTo(
          size.width,
          0,
        )
        ..lineTo(
          size.width,
          cornerSize,
        ),
      paint,
    );

    // ==========================================================
    // LEFT BOTTOM
    // ==========================================================

    canvas.drawPath(
      Path()
        ..moveTo(
          0,
          size.height -
              cornerSize,
        )
        ..lineTo(
          0,
          size.height,
        )
        ..lineTo(
          cornerSize,
          size.height,
        ),
      paint,
    );

    // ==========================================================
    // RIGHT BOTTOM
    // ==========================================================

    canvas.drawPath(
      Path()
        ..moveTo(
          size.width -
              cornerSize,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height -
              cornerSize,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}