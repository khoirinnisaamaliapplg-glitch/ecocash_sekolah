import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/core/session_socket.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/konfirmasi.dart';
import 'package:ecocash_sekolah/app_footer.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // ============================================================
  // PALET WARNA & KONSTANTA STYLING (DESIGN TOKENS)
  // ============================================================
  static const Color _primaryRed = Color(0xFFD32F2F);
  static const Color _primaryRedDark = Color(0xFFB71C1C);
  static const Color _softRedBg = Color(0xFFFEF2F2);
  static const Color _softRedBorder = Color(0xFFFECACA);
  static const Color _softRedIconBg = Color(0xFFFEE2E2);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF475569);
  static const Color _textMuted = Color(0xFF64748B);

  String? _qrIdentifier;
  bool _isLoading = true;
  bool _isRegenerating = false;
  String? _errorMessage;

  Timer? _pollingTimer;
  bool _isCheckingSession = false;
  bool _hasNavigated = false;
  int _secondsWaiting = 0;
  final int _maxWaitSeconds = 45; // Menampilkan bantuan setelah 45 detik

  /// Kanal live `/sessions`: `session:started` datang lebih cepat daripada
  /// polling, jadi layer ini yang utama dan polling hanya fallback.
  SessionSocket? _sessionSocket;
  bool _isSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _sessionSocket?.disconnect();
    super.dispose();
  }

  // ============================================================
  // LIVE CHANNEL (/sessions)
  // ============================================================

  void _connectSocket() {
    _sessionSocket = SessionSocket(
      onStarted: _handleSessionStarted,
      onConnectionChanged: (bool connected) {
        _isSocketConnected = connected;

        /*
         * Setelah connect/reconnect ambil satu snapshot: bisa saja mesin
         * sudah membuka sesi saat socket sedang mati.
         */
        if (connected) {
          _checkForOpenSession();
        } else {
          // Socket tidak bisa dipakai (misal proxy tanpa upgrade header):
          // kembali ke polling supaya QR tetap berfungsi.
          _startSessionPolling();
        }
      },
    );

    _sessionSocket!.connect();
  }

  /// `session:started` — mesin baru saja memindai QR pengguna.
  void _handleSessionStarted(Map<String, dynamic> event) {
    if (!mounted || _hasNavigated) return;

    final int? sessionId = int.tryParse('${event['sessionId'] ?? ''}');

    if (sessionId == null) return;

    debugPrint('SOCKET session:started -> $sessionId');

    _navigateToSessionDetail(sessionId);
  }

  Future<void> _initializePage() async {
    if (!ApiConfig.hasToken) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      });
      return;
    }

    // Dengarkan sesi baru sejak QR ditampilkan.
    _connectSocket();

    await _fetchQrCredential();
  }

  /// Menerjemahkan error API menjadi pesan yang bisa dibaca pengguna.
  String _describeApiError(Object error) {
    if (error is ApiException) {
      if (error.isUnauthorized) {
        return 'Sesi login telah berakhir. Silakan login kembali.';
      }

      if (error.isEmailNotVerified) {
        return 'Email Anda belum diverifikasi. '
            'Harap verifikasi email Anda terlebih dahulu.';
      }

      return error.message;
    }

    return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
  }

  // Ambil Kredensial QR Permanen Pengguna (GET /users/me/credential-qr)
  Future<void> _fetchQrCredential() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> data = await ApiClient.getMap(
        ApiConfig.getMyCredentialQr,
      );

      final String? identifier = data['identifier']?.toString().trim();
      if (identifier == null || identifier.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Identifier QR kosong.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _qrIdentifier = identifier;
        _isLoading = false;
        _errorMessage = null;
        _secondsWaiting = 0;
      });

      // Mulai polling sesi terbuka via GET /machine-sessions/current
      _startSessionPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _describeApiError(e);
      });
    }
  }

  // Regenerasi Kredensial QR Baru (POST /users/me/credential-qr/regenerate)
  Future<void> _regenerateQrCredential() async {
    setState(() => _isRegenerating = true);
    try {
      final dynamic payload = await ApiClient.post(
        ApiConfig.regenerateMyCredentialQr,
      );

      final String? newIdentifier = payload is Map
          ? payload['identifier']?.toString().trim()
          : null;

      if (newIdentifier != null && newIdentifier.isNotEmpty && mounted) {
        setState(() {
          _qrIdentifier = newIdentifier;
          _secondsWaiting = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode QR berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui QR. Coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui QR: ${_describeApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  // FALLBACK: polling GET /machine-sessions/current tiap 2 detik.
  // Hanya berjalan saat socket tidak tersambung.
  void _startSessionPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _hasNavigated) return;
      if (_isSocketConnected) return;
      _checkForOpenSession();
    });
  }

  Future<void> _checkForOpenSession({bool isManualCheck = false}) async {
    if (!mounted || _hasNavigated || _isCheckingSession) return;
    _isCheckingSession = true;

    if (!isManualCheck) {
      setState(() {
        _secondsWaiting += 2;
      });
    }

    try {
      // ApiClient mengembalikan `data` (null kalau belum ada sesi terbuka).
      final dynamic payload = await ApiClient.get(ApiConfig.getCurrentSession);

      // Jika mesin sudah scan QR dan membuka sesi
      // (status ACTIVE atau WAITING_CONFIRMATION).
      if (payload is Map && payload['id'] != null) {
        final int? sessionId = int.tryParse(payload['id'].toString());
        final String status = (payload['status'] ?? '')
            .toString()
            .toUpperCase();

        if (sessionId != null &&
            (status == 'ACTIVE' || status == 'WAITING_CONFIRMATION')) {
          _navigateToSessionDetail(sessionId);
          return;
        }
      }

      // Notifikasi jika pengecekan manual dan belum terdeteksi
      if (isManualCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mesin belum memindai QR. Arahkan layar ke kamera scanner mesin.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Polling error /machine-sessions/current: $e');
    } finally {
      _isCheckingSession = false;
    }
  }

  void _navigateToSessionDetail(int sessionId) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _pollingTimer?.cancel();
    // Layar berikutnya membuka kanal live-nya sendiri.
    _sessionSocket?.disconnect();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        // Pada EcoCash Sekolah, SetorSampahScreen versi terlampir
        // hanya menerima sessionId.
        builder: (context) => SetorSampahScreen(sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimeout = _secondsWaiting >= _maxWaitSeconds && !_hasNavigated;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildHeader(context, isTimeout, constraints.maxHeight),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isTimeout,
    double minViewportHeight,
  ) {
    final double topInset = MediaQuery.of(context).padding.top;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double heroHeight = 305 + topInset;
    final double sheetTopOffset = 252 + topInset;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ============================================================
        // HERO BACKGROUND MERAH + MASKOT HARIMAU DI SISI KANAN
        // ============================================================
        Container(
          height: heroHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8C0F15), Color(0xFF99141A), Color(0xFFA61921)],
            ),
          ),
          child: Stack(
            children: [
              // Ilustrasi Maskot Harimau di Kanan (digeser ke bawah agar kepala utuh)
              Positioned(
                right: 0,
                bottom: 8,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    // Hanya memotong area putih tipis di tepi atas bg3-new.png
                    // tanpa menyentuh margin merah di atas telinga maskot
                    heightFactor: 0.915,
                    child: Image.asset(
                      'assets/bg3-new.png',
                      width: (screenWidth * 0.52).clamp(185.0, 230.0),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/bg3.png',
                          width: (screenWidth * 0.52).clamp(185.0, 230.0),
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomRight,
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Konten Teks & Navigasi Kiri (Top Bar tetap utuh)
              Padding(
                padding: EdgeInsets.only(
                  top: topInset + 14,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Navigasi Atas
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _pollingTimer?.cancel();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Setor Sampah',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Kartu Instruksi Transparan di Sisi Kiri (tidak menutupi wajah maskot)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.53),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF5A080C,
                          ).withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Arahkan kode QR ini ke kamera mesin EcoCash.\nMesin akan otomatis mengenali akun Anda.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ============================================================
        // BOTTOM SHEET KONTEN QR & AKSI
        // ============================================================
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: sheetTopOffset),
          constraints: BoxConstraints(
            minHeight: (minViewportHeight - sheetTopOffset).clamp(
              0.0,
              double.infinity,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indikator Drag Handle Pill
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Tunjukkan Kode QR',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 20),

              // Wadah Gambar QR
              Container(
                width: 224,
                height: 224,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CustomBarcodeFrame(size: 196),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildQrContent(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: _primaryRed,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'QR Identitas EcoCash Sekolah',
                    style: TextStyle(
                      color: _primaryRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Kode QR ini merupakan identitas akun EcoCash Sekolah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12, height: 1.35),
              ),

              const SizedBox(height: 20),

              // Banner panduan / Bantuan jika timeout
              if (isTimeout)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum terdeteksi oleh mesin? Pastikan layar terang dan posisikan QR tepat di depan scanner, atau tanyakan ke petugas.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.orange.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              /*
               * Kartu tips, bukan gambar: `assets/banner2.jpeg` tidak pernah ada
               * di repo (dan tidak terdaftar di pubspec), jadi Image.asset di
               * sini hanya akan menghasilkan ruang kosong.
               */
              else
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _softRedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _softRedBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _softRedIconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: _primaryRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tunjukkan QR ini ke kamera mesin. Layar akan '
                          'memperbarui otomatis setelah mesin memindainya.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Tombol Regenerate QR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: (_isLoading || _isRegenerating)
                      ? null
                      : _regenerateQrCredential,
                  icon: _isRegenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryRed,
                          ),
                        )
                      : const Icon(Icons.refresh, color: _primaryRed, size: 20),
                  label: Text(
                    _isRegenerating
                        ? 'Memperbarui...'
                        : 'Perbarui / Buat QR Baru',
                    style: const TextStyle(
                      color: _primaryRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _primaryRed, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tombol Cek Manual
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_isLoading || _qrIdentifier == null)
                      ? null
                      : [
                          BoxShadow(
                            color: _primaryRed.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _qrIdentifier == null)
                      ? null
                      : () => _checkForOpenSession(isManualCheck: true),
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Cek Status Sambungan Mesin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLoading || _qrIdentifier == null)
                        ? Colors.grey.shade400
                        : _primaryRed,
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Footer di dalam lembar putih
              const AppFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryRed));
    }

    if (_qrIdentifier != null && _qrIdentifier!.trim().isNotEmpty) {
      return Center(
        child: QrImageView(
          data: _qrIdentifier!,
          version: QrVersions.auto,
          size: 174,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: _textPrimary,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: _textPrimary,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 34),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Gagal memuat QR EcoCash.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchQrCredential,
              style: TextButton.styleFrom(foregroundColor: _primaryRed),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBarcodeFrame extends StatelessWidget {
  final double size;
  const CustomBarcodeFrame({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: BarcodeFramePainter()),
    );
  }
}

class BarcodeFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const double corner = 28;
    const double radius = 10;

    // Kiri Atas
    canvas.drawPath(
      Path()
        ..moveTo(0, corner)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(corner, 0),
      paint,
    );
    // Kanan Atas
    canvas.drawPath(
      Path()
        ..moveTo(size.width - corner, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, corner),
      paint,
    );
    // Kiri Bawah
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - corner)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(corner, size.height),
      paint,
    );
    // Kanan Bawah
    canvas.drawPath(
      Path()
        ..moveTo(size.width - corner, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - radius,
        )
        ..lineTo(size.width, size.height - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
