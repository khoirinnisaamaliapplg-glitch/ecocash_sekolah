import 'package:flutter/material.dart';

class BantuanPage extends StatelessWidget {
  const BantuanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F7),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
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

                  const Expanded(
                    child: Text(
                      'Bantuan Bencana',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 35,
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
                        // ICON
                        Container(
                          width: 105,
                          height: 105,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.engineering_rounded,
                            size: 58,
                            color: Color(0xFFE53935),
                          ),
                        ),

                        const SizedBox(height: 25),

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

                        const Text(
                          'Kami sedang menyiapkan fitur Bantuan Bencana agar dapat digunakan dengan lebih baik.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF777777),
                          ),
                        ),

                        const SizedBox(height: 25),

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

            // FOOTER
            const Padding(
              padding: EdgeInsets.only(bottom: 25),
              child: Text(
                '❤️ Peduli dan berbagi untuk sesama',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF999999),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
