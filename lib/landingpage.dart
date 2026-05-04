import 'package:ecocash_sekolah/Auth/login.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const EcoCashKidsApp());
}

class EcoCashKidsApp extends StatelessWidget {
  const EcoCashKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCash Kids - Splash',
      theme: ThemeData(
        primaryColor: const Color(0xFF54D2F4),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const SplashLandingPage(),
    );
  }
}

class SplashLandingPage extends StatefulWidget {
  const SplashLandingPage({super.key});

  @override
  State<SplashLandingPage> createState() => _SplashLandingPageState();
}

class _SplashLandingPageState extends State<SplashLandingPage> {
  @override
  void initState() {
    super.initState();
    // Navigasi otomatis ke login setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- BAGIAN TENGAH (LOGO) ---
            // Menggunakan Expanded agar Area ini mengambil semua sisa ruang
            // dan konten di dalamnya bisa diletakkan di tengah secara vertikal.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    40.0,
                  ), // Padding agar logo tidak terlalu mepet
                  child: Image.asset(
                    // --- PENTING ---
                    // Ganti dengan path file logo Anda.
                    // Contoh: 'assets/images/logo_ecocash_kids.png'
                    // Pastikan file sudah terdaftar di pubspec.yaml
                    'assets/logokids.png',
                    fit: BoxFit.contain, // Memastikan logo muat tanpa terpotong
                    // Anda bisa mengatur height jika perlu batasan spesifik
                    // height: 300,
                  ),
                ),
              ),
            ),

            // --- BAGIAN BAWAH (FOOTER) ---
            // --- BAGIAN BAWAH (FOOTER) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mengganti Icon dengan Image.asset untuk logo perusahaan
                  Image.asset(
                    'assets/logoideas.png', // Sesuaikan dengan path logo perusahaan Anda
                    height:
                        40, // Ukuran disesuaikan agar proporsional sebagai footer
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),

                  // Teks Hak Cipta
                  const Text(
                    "Copyright © 2025 Ecocash",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
                  ),

                  // Teks Pembuat
                  const Text(
                    "Created by: PT Ideas Edvolution Technology",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
