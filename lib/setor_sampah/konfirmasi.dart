import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/transaksi.dart';

class SetorSampahScreen extends StatefulWidget {
  final String? sessionId;

  const SetorSampahScreen({super.key, this.sessionId});

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  bool _isLoading = false;

  // --- LOGIKA KONFIRMASI SESI (USER KLIK SELESAI) ---
  Future<void> _handleConfirm() async {
    // 1. Validasi ID Sesi
    if (widget.sessionId == null || widget.sessionId!.isEmpty) {
      _showSnackBar(
        "ID Sesi tidak valid atau sudah kadaluwarsa",
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Gunakan endpoint CONFIRM dari ApiConfig
      final String url = ApiConfig.confirmSession(widget.sessionId!);

      debugPrint("Menghubungi Server: $url");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );

      // 3. Cek Response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint("Success: ${responseData['message']}");

        _showSnackBar("Konfirmasi Berhasil! Saldo ditambahkan.", Colors.green);

        // Beri jeda 1 detik agar user bisa baca SnackBar
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // Pindah ke halaman Berhasil dan KIRIM DATA hasil API
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => TransaksiBerhasilScreen(
                detailTransaksi: responseData, // Data dikirim ke sini
              ),
            ),
            (route) => route.isFirst,
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar(
          errorData['message'] ?? "Gagal konfirmasi. Cek status di mesin.",
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("Error Catch: $e");
      _showSnackBar(
        "Koneksi terputus. Pastikan server AIoT aktif.",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _buildHeader(context),
                Positioned(
                  top: 150,
                  left: 20,
                  right: 20,
                  child: _buildScanResultCard(),
                ),
              ],
            ),
            const SizedBox(height: 550),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
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
    );
  }

  Widget _buildScanResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Scan Berhasil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Barang daur ulangmu sudah dipindai dan\nsilahkan cek untuk mengkonfirmasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 25),
          _buildDetailBox(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF388E3C),
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Konfirmasi SDU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDetailBox() {
    // Bagian ini masih statis karena hanya untuk preview sebelum konfirmasi.
    // Setelah diklik konfirmasi, data asli dari backend akan muncul di halaman transaksi.
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Setoran Sampah',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildStatus(),
            ],
          ),
          const Divider(height: 30),
          _buildItemRow('Data sedang dimuat...', '-', '-'),
          const Divider(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Penjualan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '---',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Menunggu',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemRow(String name, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.black87)),
          Text(qty, style: const TextStyle(color: Colors.grey)),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
