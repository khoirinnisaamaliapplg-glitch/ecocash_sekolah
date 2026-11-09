import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/konfirmasi.dart';
import 'package:ecocash_sekolah/app_footer.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _qrIdentifier;
  bool _isLoading = true;
  bool _isRegenerating = false;
  String? _errorMessage;

  Timer? _pollingTimer;
  bool _isCheckingSession = false;
  bool _hasNavigated = false;
  int _secondsWaiting = 0;
  final int _maxWaitSeconds = 45; // Menampilkan bantuan setelah 45 detik

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

  Future<void> _initializePage() async {
    if (!ApiConfig.hasToken) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      });
      return;
    }
    await _fetchQrCredential();
  }

  // Ambil Kredensial QR Permanen Pengguna (GET /users/me/credential-qr)
  Future<void> _fetchQrCredential() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyCredentialQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi login telah berakhir. Silakan login kembali.';
        });
        return;
      }

      if (response.statusCode == 403) {
        dynamic body;
        try { body = jsonDecode(response.body); } catch (_) { body = null; }
        final code = body is Map ? body['code']?.toString() ?? '' : '';
        if (code == 'EMAIL_NOT_VERIFIED' || response.body.contains('EMAIL_NOT_VERIFIED')) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'Email Anda belum diverifikasi. Harap verifikasi email Anda terlebih dahulu.';
          });
          return;
        }
      }

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat QR (${response.statusCode}). Coba lagi.';
        });
        return;
      }

      final body = jsonDecode(response.body);
      final data = body['data'];

      if (data == null || data is! Map) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Format kredensial QR tidak valid.';
        });
        return;
      }

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
        _errorMessage = 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
      });
    }
  }

  // Regenerasi Kredensial QR Baru (POST /users/me/credential-qr/regenerate)
  Future<void> _regenerateQrCredential() async {
    setState(() => _isRegenerating = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.regenerateMyCredentialQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic body = jsonDecode(response.body);
        final dynamic data = body is Map ? body['data'] : null;
        final newIdentifier = data is Map ? data['identifier']?.toString().trim() : null;

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
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui QR (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koneksi bermasalah: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  // Polling Sesi Berjalan (GET /machine-sessions/current tiap 2 detik)
  void _startSessionPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _hasNavigated) return;
      _checkForOpenSession();
    });
  }

  Future<void> _checkForOpenSession({bool isManualCheck = false}) async {
    if (!mounted || _hasNavigated || _isCheckingSession) return;
    _isCheckingSession = true;

    if (!isManualCheck) {
      setState(() { _secondsWaiting += 2; });
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getCurrentSession),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final dynamic sessionData = body is Map ? body['data'] : null;

        // Jika mesin sudah scan QR dan membuka sesi (status ACTIVE atau WAITING_CONFIRMATION)
        if (sessionData != null && sessionData is Map && sessionData['id'] != null) {
          final int? sessionId = int.tryParse(sessionData['id'].toString());
          final String status = (sessionData['status'] ?? '').toString().toUpperCase();

          if (sessionId != null && (status == 'ACTIVE' || status == 'WAITING_CONFIRMATION')) {
            _navigateToSessionDetail(sessionId);
            return;
          }
        }
      }

      // Notifikasi jika pengecekan manual dan belum terdeteksi
      if (isManualCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesin belum memindai QR. Arahkan layar ke kamera scanner mesin.'),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  _buildHeader(context, isTimeout),
                  const SizedBox(height: 16),
                  const AppFooter(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTimeout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg3.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  _pollingTimer?.cancel();
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                'Setor Sampah',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        Container(
          margin: const EdgeInsets.only(top: 130, left: 20, right: 20, bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tunjukkan Kode QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Arahkan kode QR ini ke kamera mesin EcoCash.\nMesin akan otomatis mengenali akun Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 25),

              // Wadah Gambar QR
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildQrContent(),
                    ),
                  ),
                  const CustomBarcodeFrame(size: 230),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 17, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'QR Identitas EcoCash Sekolah',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kode QR ini merupakan identitas akun EcoCash Sekolah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // Banner panduan / Bantuan jika timeout
              if (isTimeout)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belum terdeteksi oleh mesin? Pastikan layar terang dan posisikan QR tepat di depan scanner, atau tanyakan ke petugas.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade900, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Image.asset(
                  'assets/banner2.jpeg',
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(height: 8),
                ),
              const SizedBox(height: 20),

              // Tombol Regenerate QR
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isLoading || _isRegenerating) ? null : _regenerateQrCredential,
                  icon: _isRegenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, color: Colors.green),
                  label: Text(
                    _isRegenerating ? 'Memperbarui...' : 'Perbarui / Buat QR Baru',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Cek Manual
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _qrIdentifier == null)
                      ? null
                      : () => _checkForOpenSession(isManualCheck: true),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text(
                    'Cek Status Sambungan Mesin',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLoading || _qrIdentifier == null) ? Colors.grey : const Color(0xFF388E3C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    if (_qrIdentifier != null && _qrIdentifier!.trim().isNotEmpty) {
      return Center(
        child: QrImageView(
          data: _qrIdentifier!,
          version: QrVersions.auto,
          size: 180,
          backgroundColor: Colors.white,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 36),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Gagal memuat QR EcoCash.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _fetchQrCredential,
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
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double corner = 36;

    // Kiri Atas
    canvas.drawPath(Path()..moveTo(0, corner)..lineTo(0, 0)..lineTo(corner, 0), paint);
    // Kanan Atas
    canvas.drawPath(Path()..moveTo(size.width - corner, 0)..lineTo(size.width, 0)..lineTo(size.width, corner), paint);
    // Kiri Bawah
    canvas.drawPath(Path()..moveTo(0, size.height - corner)..lineTo(0, size.height)..lineTo(corner, size.height), paint);
    // Kanan Bawah
    canvas.drawPath(Path()..moveTo(size.width - corner, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - corner), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}