import 'package:flutter/material.dart';

class CheckEmailPage extends StatelessWidget {
  final String email;

  const CheckEmailPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // =================================================
                  // LOGO
                  // =================================================
                  Image.asset(
                    'assets/logo.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 50),

                  // =================================================
                  // EMAIL ICON
                  // =================================================
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 52,
                      color: Color(0xFF2E7D32),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // TITLE
                  // =================================================
                  const Text(
                    'Periksa Email Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D2939),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Kami telah mengirimkan link verifikasi ke',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667085), fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  // =================================================
                  // EMAIL
                  // =================================================
                  SelectableText(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // =================================================
                  // DESCRIPTION
                  // =================================================
                  const Text(
                    'Buka email tersebut kemudian tekan tombol '
                    '"Verify Email". Setelah link dibuka, EcoCash '
                    'akan memverifikasi akun Anda secara otomatis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF667085),
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            'Belum menemukan email? '
                            'Periksa folder Spam, Junk, atau Promotions.',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 45),

                  // =================================================
                  // BACK LOGIN
                  // =================================================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Kembali ke Login',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
