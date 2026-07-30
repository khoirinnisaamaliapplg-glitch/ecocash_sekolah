import 'dart:async';
import 'dart:convert';

import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/konfirmasi.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _qrToken;

  bool _isLoading = true;
  bool _isCheckingSession = false;
  bool _hasNavigated = false;

  Timer? _timer;

  int _secondsLeft = 30;
  int _pollCounter = 0;

  @override
  void initState() {
    super.initState();

    // Mengambil QR ketika halaman pertama kali dibuka.
    _fetchQrToken();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Mengecek apakah QR sudah dipindai oleh mesin.
  ///
  /// Endpoint yang digunakan:
  /// GET /users/access-tokens/{tokenId}
  ///
  /// Contoh respons:
  /// {
  ///   "data": {
  ///     "id": "...",
  ///     "isUsed": true,
  ///     "expiresAt": "...",
  ///     "machineSession": {
  ///       "id": 12,
  ///       "status": "ACTIVE"
  ///     }
  ///   }
  /// }
  Future<void> _checkSessionStatus() async {
    if (_qrToken == null ||
        _qrToken!.isEmpty ||
        _isCheckingSession ||
        _hasNavigated) {
      return;
    }

    _isCheckingSession = true;

    try {
      final response = await http.get(
        Uri.parse(
          ApiConfig.getSessionStatus(_qrToken!),
        ),
        headers: ApiConfig.headers,
      );

      if (!mounted || _hasNavigated) {
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body) as Map<String, dynamic>;

        final dynamic data = responseData['data'];
        final dynamic machineSession = data?['machineSession'];

        if (machineSession != null) {
          final dynamic rawSessionId = machineSession['id'];
          final int? sessionId = _parseSessionId(rawSessionId);

          final String status =
              machineSession['status']?.toString().toUpperCase() ?? '';

          debugPrint(
            'ScanPage Sekolah: QR dipindai. '
            'sessionId=$sessionId, status=$status',
          );

          if (sessionId != null) {
            _openConfirmationPage(sessionId);
          }
        }
      } else {
        debugPrint(
          'Gagal memeriksa sesi. '
          'Status: ${response.statusCode}, '
          'Response: ${response.body}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error ketika memeriksa sesi mesin: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isCheckingSession = false;
    }
  }

  /// Timer:
  /// 1. Mengurangi countdown setiap satu detik.
  /// 2. Memeriksa sesi mesin setiap dua detik.
  /// 3. Mengambil QR baru setelah waktu habis.
  void _startTimer() {
    _timer?.cancel();

    _pollCounter = 0;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted || _hasNavigated) {
          timer.cancel();
          return;
        }

        _pollCounter++;

        // Cek status pemindaian mesin setiap dua detik.
        if (_pollCounter >= 2) {
          _pollCounter = 0;
          _checkSessionStatus();
        }

        if (_secondsLeft > 0) {
          setState(() {
            _secondsLeft--;
          });
        } else {
          timer.cancel();
          _fetchQrToken();
        }
      },
    );
  }

  /// Mengambil token QR baru dari backend.
  Future<void> _fetchQrToken() async {
    if (!mounted || _hasNavigated) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _isLoading = true;
      _qrToken = null;
      _secondsLeft = 30;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyQr),
        headers: ApiConfig.headers,
      );

      if (!mounted || _hasNavigated) {
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body) as Map<String, dynamic>;

        final String? newToken =
            responseData['data']?['token']?.toString();

        if (newToken == null || newToken.isEmpty) {
          throw Exception(
            'Token QR tidak ditemukan pada respons server.',
          );
        }

        setState(() {
          _qrToken = newToken;
          _secondsLeft = 30;
          _isLoading = false;
        });

        _startTimer();
      } else {
        throw Exception(
          'Gagal mengambil QR. '
          'Status: ${response.statusCode}. '
          'Response: ${response.body}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error ketika mengambil token QR: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || _hasNavigated) {
        return;
      }

      setState(() {
        _isLoading = false;

        // Mencoba kembali setelah lima detik.
        _secondsLeft = 5;
      });

      _showSnackBar(
        'Gagal mengambil kode QR. Sistem akan mencoba kembali.',
        Colors.red,
      );

      _startRetryTimer();
    }
  }

  /// Timer khusus ketika pengambilan QR gagal.
  void _startRetryTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted || _hasNavigated) {
          timer.cancel();
          return;
        }

        if (_secondsLeft > 0) {
          setState(() {
            _secondsLeft--;
          });
        } else {
          timer.cancel();
          _fetchQrToken();
        }
      },
    );
  }

  /// Tombol konfirmasi manual.
  Future<void> _continueManually() async {
    if (_qrToken == null ||
        _qrToken!.isEmpty ||
        _isLoading ||
        _hasNavigated) {
      return;
    }

    setState(() {
      _isCheckingSession = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          ApiConfig.getSessionStatus(_qrToken!),
        ),
        headers: ApiConfig.headers,
      );

      if (!mounted || _hasNavigated) {
        return;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body) as Map<String, dynamic>;

        final dynamic machineSession =
            responseData['data']?['machineSession'];

        if (machineSession != null) {
          final int? sessionId = _parseSessionId(
            machineSession['id'],
          );

          if (sessionId != null) {
            _openConfirmationPage(sessionId);
            return;
          }
        }

        _showSnackBar(
          'Mesin belum memindai QR. Arahkan QR ke scanner mesin.',
          Colors.orange,
        );
      } else {
        _showSnackBar(
          'Gagal memeriksa status mesin.',
          Colors.red,
        );
      }
    } catch (error) {
      debugPrint(
        'Error konfirmasi manual: $error',
      );

      if (mounted) {
        _showSnackBar(
          'Terjadi kesalahan saat memeriksa mesin.',
          Colors.red,
        );
      }
    } finally {
      if (mounted && !_hasNavigated) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  /// Berpindah ke halaman konfirmasi.
  void _openConfirmationPage(int sessionId) {
    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;
    _timer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          return SetorSampahScreen(
            sessionId: sessionId,
          );
        },
      ),
    );
  }

  int? _parseSessionId(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

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
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          padding: const EdgeInsets.only(
            top: 60,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg3.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  'Setor Sampah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Menggunakan margin, bukan Positioned, agar tinggi Stack
        // mengikuti seluruh isi kartu dan tidak terpotong.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            top: 130,
            left: 20,
            right: 20,
            bottom: 30,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tunjukkan Kode QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E50),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Arahkan kode QR ini ke scanner mesin.\n'
                'Sistem akan mendeteksi identitas dan\n'
                'memulai sesi transaksi Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 35),
              LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final double qrContainerSize =
                      constraints.maxWidth < 230
                      ? constraints.maxWidth
                      : 220;

                  final double frameSize =
                      constraints.maxWidth < 240
                      ? constraints.maxWidth
                      : 230;

                  final double qrSize =
                      qrContainerSize - 40;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: qrContainerSize,
                        height: qrContainerSize,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(18),
                          child: _buildQrContent(qrSize),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomBarcodeFrame(
                          size: frameSize,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _isLoading && _qrToken == null
                          ? 'Mencoba kembali dalam $_secondsLeft detik'
                          : 'Berubah dalam $_secondsLeft detik',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : _fetchQrToken,
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                  ),
                  label: const Text(
                    'Refresh Kode',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    side: const BorderSide(
                      color: Colors.green,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading ||
                          _qrToken == null ||
                          _isCheckingSession)
                      ? null
                      : _continueManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor:
                        Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCheckingSession
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                        )
                      : const Text(
                          'Lanjut ke Konfirmasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Halaman akan berpindah otomatis setelah QR dipindai mesin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
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

  Widget _buildQrContent(double qrSize) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    if (_qrToken == null || _qrToken!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Gagal memuat QR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Center(
      child: QrImageView(
        data: _qrToken!,
        version: QrVersions.auto,
        size: qrSize,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

class CustomBarcodeFrame extends StatelessWidget {
  final double size;

  const CustomBarcodeFrame({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BarcodeFramePainter(),
      ),
    );
  }
}

class BarcodeFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerSize = 40;

    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(
          size.width - cornerSize,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height - cornerSize,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}