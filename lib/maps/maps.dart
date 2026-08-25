import 'package:flutter/material.dart';

class MapsPage extends StatelessWidget {
  const MapsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F7),
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // HEADER
            // =========================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  // Tombol Back
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Judul
                  const Expanded(
                    child: Text(
                      'Maps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Icon kanan
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // KONTEN UTAMA
            // =========================
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =========================
                        // ICON UTAMA
                        // =========================
                        Container(
                          width: 105,
                          height: 105,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 58,
                            color: Color(0xFFE53935),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Judul
                        const Text(
                          'Fitur Sedang\nDalam Pengembangan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF333333),
                          ),
                        ),

                        const SizedBox(height: 13),

                        // Deskripsi
                        const Text(
                          'Kami sedang menyiapkan fitur Maps '
                          'untuk membantu kamu menemukan lokasi '
                          'dengan lebih mudah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF777777),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Badge Segera Hadir
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFFE53935),
                                size: 19,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Segera Hadir!',
                                style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // =========================
            // FOOTER
            // =========================
            const Padding(
              padding: EdgeInsets.only(bottom: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Color(0xFFE53935),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Temukan lokasi dengan lebih mudah',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
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