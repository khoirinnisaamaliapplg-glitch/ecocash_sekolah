import 'dart:convert';
import 'package:ecocash_sekolah/refund/refund.dart';
import 'package:ecocash_sekolah/saldo/saldo.dart';
import 'package:ecocash_sekolah/setor_sampah/scan.dart';
import 'package:ecocash_sekolah/transfer/transfer.dart';
import 'package:ecocash_sekolah/ecomer/ecomer.dart';
import 'package:ecocash_sekolah/maps/maps.dart';
import 'package:ecocash_sekolah/bantuan/bantuan.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_sekolah/ipconfig.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>> _fetchUserData() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getMyWallet),
      headers: {
        'Authorization': 'Bearer ${ApiConfig.userToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Gagal memuat profil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 450, child: _buildHeader(context, data)),
                const SizedBox(height: 40),
                _buildCombinedPaymentMenu(context),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 320,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg8.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: _buildBalanceCard(context, data),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, Map<String, dynamic> data) {
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
          Row(
            children: [
              Image.asset('assets/icons/dompet.png', height: 45, width: 45),
              const SizedBox(width: 15),
              Text(
                "Rp${data['balance'] ?? '0'}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                "Carbon Saved:",
                "${data['carbon'] ?? '0'} Kg CO2",
                'assets/icons/daun.png',
              ),
              _buildStatItem(
                "Total Point:",
                "${data['points'] ?? '0'}",
                'assets/icons/star.png',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionItem(
                context,
                'assets/icons/scan.png',
                "Scan Barcode",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanPage()),
                  );
                },
              ),
              _buildActionItem(
                context,
                'assets/icons/topup.png',
                "Top Up",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IsiSaldoPage(),
                    ),
                  );
                },
              ),
              _buildActionItem(
                context,
                'assets/icons/panah.png',
                "Transfer",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransferPage(),
                    ),
                  );
                },
              ),
              _buildActionItem(
                context,
                'assets/icons/lock.png',
                "History",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RefundsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String path,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 75,
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
      ),
    );
  }

  Widget _buildCombinedPaymentMenu(BuildContext context) {
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
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7066), Color(0xFFFF8A84)],
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
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Digital Voucher",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          "Pakai",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapsPage(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuTile(
                        'assets/icons/panahb.png',
                        "Exchange balance for goods",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EcomerPage(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuTile(
                        'assets/icons/love.png',
                        "Charities",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BantuanPage(),
                          ),
                        ),
                      ),
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

  Widget _buildMenuTile(String path, String title, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Image.asset(path, height: 30, width: 30),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDivider() => const Divider(
    height: 1,
    color: Color(0xFFF5F5F5),
    indent: 20,
    endIndent: 20,
  );
}
