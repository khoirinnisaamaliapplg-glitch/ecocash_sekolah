import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ecocash_sekolah/ipconfig.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _qrToken;
  bool _isLoading = true;
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _fetchQrToken(); // Ambil token saat halaman dibuka
    _startTimer(); // Jalankan countdown
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hentikan timer saat pindah halaman
    super.dispose();
  }

  // Timer untuk hitung mundur 30 detik
  // 1. LOGIKA TIMER: Mematikan timer lama sebelum buat yang baru agar tidak tumpang tindih
  // 1. LOGIKA TIMER (Hanya mengatur angka dan pemicu)
  // 1. Perbaikan Logika Timer (Dibersihkan agar tidak menumpuk)
  void _startTimer() {
    _timer?.cancel(); // MATIKAN timer lama setiap kali fungsi dipanggil
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _fetchQrToken(); // Otomatis panggil saat detik ke-0
        }
      });
    });
  }

  // 2. Perbaikan Logika Fetch (Sinkronisasi Data)
  Future<void> _fetchQrToken() async {
    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isLoading = true;
      _qrToken = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyQr),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Ambil token dari dalam nested object 'data'
        String? newToken = responseData['data']?['token']?.toString();

        if (mounted) {
          setState(() {
            _qrToken = newToken;
            _secondsLeft = 30;
            _isLoading = false;
          });
          _startTimer();
        }
      } else {
        throw Exception("Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error Logic: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _secondsLeft = 5;
        });
        _startTimer();
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(
              height: 580,
            ), // Menjaga scroll area sesuai layout asli
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Header Hijau
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
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
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
              const Text(
                'Setor Sampah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // --- Main Card (Tampilan QR) ---
        Positioned(
          top: 130,
          left: 20,
          right: 20,
          child: Container(
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Arahkan kode QR ini ke scanner mesin,\nAI akan otomatis mendeteksi identitas\ndan memulai sesi transaksi Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 35),

                // --- AREA QR DENGAN FRAME ---
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.green,
                                ),
                              )
                            : (_qrToken != null
                                  ? Center(
                                      child: QrImageView(
                                        data: _qrToken!,
                                        version: QrVersions.auto,
                                        size: 180.0,
                                      ),
                                    )
                                  : const Center(
                                      child: Text("Gagal memuat QR"),
                                    )),
                      ),
                    ),
                    // Frame Sudut Hijau (Tetap Pakai Painter Kamu)
                    CustomBarcodeFrame(size: 230),
                  ],
                ),

                const SizedBox(height: 15),

                // Timer Indikator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Berubah dalam $_secondsLeft detik",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // --- Maskot (Sesuai Layout Asli) ---
                Image.asset(
                  'assets/bgscan.png',
                  height: 200,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(height: 200),
                ),

                const SizedBox(height: 20),

                // Tombol Refresh Manual
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _fetchQrToken,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Refresh Kode",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- WIDGET FRAME (ASLI DARI KODEMU) ---
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
    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double cornerSize = 40;

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
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
