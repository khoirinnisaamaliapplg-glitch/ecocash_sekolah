import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Menggunakan warna biru 54D2F4 sebagai aksen utama
    const Color primaryBlue = Color(0xFF54D2F4);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            // Jarak yang pas agar menu di bawah kartu saldo tidak tertutup
            const SizedBox(height: 170),
            _buildCombinedPaymentMenu(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Header yang tingginya sudah disesuaikan agar tidak terlalu bawah
        Container(
          height: 320,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg8.png'),
              fit: BoxFit.cover,
              alignment:
                  Alignment.topCenter, // Memastikan maskot tidak tertutup
            ),
          ),
        ),
        // Kartu Saldo (Balance Card)
        Positioned(
          bottom: -130,
          left: 20,
          right: 20,
          child: _buildBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris Saldo
          Row(
            children: [
              Image.asset('assets/icons/dompet.png', height: 45, width: 45),
              const SizedBox(width: 15),
              const Text(
                "Rp150.000",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Statistik (Carbon & Point)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                "Carbon Saved:",
                "0,5 Kg CO2",
                'assets/icons/daun.png',
              ),
              _buildStatItem("Total Point:", "500", 'assets/icons/star.png'),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 20),
          // Tombol Aksi Layanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionItem('assets/icons/scan.png', "Scan Barcode"),
              _buildActionItem('assets/icons/topup.png', "Top Up"),
              _buildActionItem('assets/icons/panah.png', "Transfer"),
              _buildActionItem('assets/icons/lock.png', "Activity"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedPaymentMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your active payment",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E50),
            ),
          ),
          const SizedBox(height: 15),
          // Container Menu Utama (Warna Merah Muda ke Merah)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7066), Color(0xFFFF8A84)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Digital Voucher",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                          side: const BorderSide(
                            color: Colors.white,
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          "Pakai",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Daftar Menu dalam Container Putih
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        'assets/icons/lokasi.png',
                        "Find nearest return point",
                      ),
                      _buildDivider(),
                      _buildMenuTile(
                        'assets/icons/panahb.png',
                        "Exchange balance for goods",
                      ),
                      _buildDivider(),
                      _buildMenuTile('assets/icons/love.png', "Charities"),
                      _buildDivider(),
                      _buildMenuTile('assets/icons/plus.png', "Other"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String path) {
    return Row(
      children: [
        Image.asset(path, height: 35, width: 35),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3E50),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(String path, String label) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Image.asset(path, height: 35, width: 35),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5A6B7D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(String path, String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Image.asset(path, height: 30, width: 30),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D3E50),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF2D3E50),
        size: 18,
      ),
      onTap: () {},
    );
  }

  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: Divider(height: 1, color: Color(0xFFF5F5F5)),
  );
}
