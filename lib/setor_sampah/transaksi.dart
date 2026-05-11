import 'package:ecocash_sekolah/setor_sampah/scan.dart';
import 'package:flutter/material.dart';

class TransaksiBerhasilScreen extends StatelessWidget {
  // 1. Variabel untuk menampung data dari backend
  final Map<String, dynamic>? detailTransaksi;

  // 2. Constructor tidak boleh 'const' karena membawa data dinamis
  const TransaksiBerhasilScreen({super.key, this.detailTransaksi});

  @override
  Widget build(BuildContext context) {
    // 3. Ekstraksi data dari response backend
    final data = detailTransaksi?['data'] ?? {};
    final List items = data['wasteTransactions'] ?? [];
    final String totalAmount = data['totalAmount']?.toString() ?? '0';
    final String sessionId = data['sessionId']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _buildHeader(context),
                Positioned(
                  top: 130,
                  left: 20,
                  right: 20,
                  child: _buildSuccessCard(items, totalAmount, sessionId),
                ),
              ],
            ),
            // Spacer agar konten card tidak tertutup bottom navbar
            const SizedBox(height: 600),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  // --- 1. HEADER HIJAU ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
        image: DecorationImage(
          image: AssetImage('assets/bg3.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
      child: const Text(
        'Setor Sampah',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- 2. CARD TRANSAKSI BERHASIL ---
  Widget _buildSuccessCard(List items, String total, String idSesi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Transaksi Berhasil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Kamu dapat bukti berisi jenis sampah dan\npoinnya. Jadi, semua tercatat rapi!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 25),

          _buildTransactionDetails(items, total, idSesi),

          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTextButton(Icons.share_outlined, 'Share'),
              _buildTextButton(Icons.file_download_outlined, 'Download'),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. DETAIL TRANSAKSI DINAMIS ---
  Widget _buildTransactionDetails(List items, String total, String idSesi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ringkasan Setoran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID Sesi: #$idSesi',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const Text(
                'Status: Berhasil',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const Divider(height: 30),

          // Me-loop data sampah dari list yang dikirim backend
          if (items.isEmpty)
            const Text("Detail sampah tidak ditemukan")
          else
            Column(
              children: items.map((item) {
                return _buildItemRow(
                  item['wasteType']?['name'] ?? 'Sampah',
                  '${item['weight']} Kg',
                  'Rp ${item['amount']}',
                  const Color(0xFFE8F5E9),
                );
              }).toList(),
            ),

          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pendapatan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp $total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. TOMBOL NAVIGASI ---
  Widget _buildBottomActions(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4CAF50)),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Reset stack dan balik ke ScanPage
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ScanPage()),
                (route) => route.isFirst,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Scan Sampah Lagi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Terkonfirmasi',
        style: TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemRow(String name, String qty, String price, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.recycling, size: 20, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                qty,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Text(
            price,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTextButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
