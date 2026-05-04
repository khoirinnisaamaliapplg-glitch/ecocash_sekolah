import 'package:flutter/material.dart';

class RiwayatPage extends StatelessWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildHistoryTitle(),
            const SizedBox(height: 20),
            _buildTabFilter(),
            const SizedBox(height: 20),
            _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  // --- Header sesuai kode awalmu ---
  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg4.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    'Pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Judul & Deskripsi ---
  Widget _buildHistoryTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // GANTI DISINI: Icon daun diganti dengan Image.asset
              Image.asset(
                'assets/icons/daun.png', // Ganti dengan path gambar daunmu
                width: 24,
                height: 24,
                // fit: BoxFit.contain, // Opsional: sesuaikan cara gambar dimuat
              ),
              const SizedBox(width: 8),
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Lihat dan pantau semua aktivitasmu secara lengkap dan teratur dalam satu tempat.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // --- Tab Filter (Semua, Setor Sampah, dll) ---
  Widget _buildTabFilter() {
    List<String> filters = ['Semua', 'Setor Sampah', 'Transfer', 'Tabungan'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = filter == 'Semua';
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
              ),
            ),
            child: Text(
              filter,
              style: TextStyle(
                color: isSelected ? Colors.green : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Daftar Transaksi ---
  Widget _buildTransactionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // GANTI DISINI: Icon daun diganti dengan Image.asset
                  Image.asset(
                    'assets/icons/daun.png', // Ganti dengan path gambar daunmu
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Terbaru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Lihat semua',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTransactionItem(
            title: 'Setor Sampah',
            subtitle: 'Transaksi ke Ecocash Buahbatu',
            id: '29405892',
            amount: 'Rp. 100.000',
            date: '19 Mei 2025',
            time: '14:53 WIB',
            status: 'dibatalkan',
            statusColor: Colors.red.shade100,
            textColor: Colors.red,
            icon: Icons.delete_outline,
          ),
          _buildTransactionItem(
            title: 'Transfer',
            subtitle: 'Transaksi ke Bank Mandiri',
            id: '29405892',
            amount: 'Rp. 100.000',
            date: '19 Mei 2025',
            time: '14:53 WIB',
            status: 'Terkonfirmasi',
            statusColor: Colors.green.shade100,
            textColor: Colors.green,
            icon: Icons.swap_horiz,
          ),
          _buildTransactionItem(
            title: 'Tabungan',
            subtitle: 'Transaksi ke Tabungan Liburan',
            id: '29405892',
            amount: 'Rp. 100.000',
            date: '19 Mei 2025',
            time: '14:53 WIB',
            status: 'Pending',
            statusColor: Colors.orange.shade100,
            textColor: Colors.orange,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String id,
    required String amount,
    required String date,
    required String time,
    required String status,
    required Color statusColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.green, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'ID Transaksi: $id',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
