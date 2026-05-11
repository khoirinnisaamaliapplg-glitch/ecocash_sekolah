import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:ecocash_sekolah/ipconfig.dart'; // Pastikan ini sudah ada dan benar
import 'package:http/http.dart' as http;

class IsiSaldoPage extends StatefulWidget {
  const IsiSaldoPage({super.key});

  @override
  State<IsiSaldoPage> createState() => _IsiSaldoPageState();
}

class _IsiSaldoPageState extends State<IsiSaldoPage> {
  bool _isLoading = true;
  String _namaAkun = "-";
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  // Fungsi untuk mengambil data dari API /wallets/me
  Future<void> _fetchWalletData() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMyWallet),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Sesuaikan key JSON ini dengan response asli API kamu
          // Biasanya formatnya data['user']['name'] atau data['balance']
          _namaAkun = data['user_name'] ?? "User";
          _balance = data['balance'] ?? 0;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load wallet');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _fetchWalletData, // Swipe down untuk refresh saldo
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [_buildHeader(context), const SizedBox(height: 100)],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  // Logika konfirmasi topup
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD3D3D3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: Text(
            _isLoading ? 'Loading...' : 'Konfirmasi',
            style: const TextStyle(
              color: Color(0xFF8E8E8E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.blue, // Fallback warna jika bg.png tidak ada
            image: DecorationImage(
              image: AssetImage('assets/bgp.png'),
              fit: BoxFit.cover,
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                'Isi Saldo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 150,
          left: 20,
          right: 20,
          child: _buildSimpleBalanceCard(),
        ),
      ],
    );
  }

  Widget _buildSimpleBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
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
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nama Akun',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _namaAkun,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF0F0F0),
                  ),
                ),
                const Text(
                  'Saldo Saat Ini',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Rp $_balance', // Kamu bisa gunakan intl package untuk format currency
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
