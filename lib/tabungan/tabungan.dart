import 'package:flutter/material.dart';

class TabunganPage extends StatelessWidget {
  const TabunganPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. HEADER SECTION (Sesuai Gambar)
          _buildHeader(context),

          // 2. BODY SECTION (Tanpa Scroll)
          // 2. BODY SECTION
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -25, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Tambahkan ini
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Deskripsi (Gunakan widget yang lebih kecil jika layar sempit)
                  const Text(
                    'Tabungan Ecocash',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Yuk, terus tambah tabunganmu!',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  // Tab Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('Semua', true),
                        _buildCategoryChip('Tabungan', false),
                        _buildCategoryChip('Deposito', false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Grid Kartu - BAGIAN KRUSIAL
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildSavingCard(
                                title: 'Utama',
                                balance: 'Rp. *****',
                                progress: '90%',
                                color: const Color(0xFF76D14D),
                                bgImage: 'assets/ijo.png',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _buildSavingCard(
                                      title: 'Sekolah',
                                      balance: 'Rp. *****',
                                      progress: '75%',
                                      color: const Color(0xFF4FC3F7),
                                      bgImage: 'assets/biru.png',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: _buildSavingCard(
                                      title: 'Liburan',
                                      balance: 'Rp. *****',
                                      progress: '10%',
                                      color: const Color(0xFF9575CD),
                                      bgImage: 'assets/ungu.png',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 3. BOTTOM BUTTONS (Sesuai Gambar)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
            child: Column(
              children: [
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Buat Baru',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Tambah Tabungan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg3.png'), // Background biru/gambar harimau
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'Tabungan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/riwayat.png',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Hi, Rashda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '1990 3038 0003',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          const Text(
            'Total Saldo',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          Row(
            children: const [
              Text(
                'Rp.1.500.000',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.visibility, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSavingCard({
    required String title,
    required String balance,
    required String progress,
    required Color color,
    required String bgImage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        image: DecorationImage(
          image: AssetImage(bgImage),
          fit: BoxFit.contain,
          alignment: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.visibility, color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                progress,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
