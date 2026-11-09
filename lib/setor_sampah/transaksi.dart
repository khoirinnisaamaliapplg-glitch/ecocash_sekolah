import 'package:flutter/material.dart';
import 'package:ecocash_sekolah/home.dart';
import 'package:ecocash_sekolah/setor_sampah/scan.dart';
import 'package:ecocash_sekolah/app_footer.dart';

/// Bukti transaksi EcoCash Sekolah, diselaraskan dengan UI EcoCash Indonesia.
/// Mendukung payload baru (`items`, `earned`, `balance`, dll.) dan payload
/// lama (`wasteTransactions`, `totalAmount`).
class TransaksiBerhasilScreen extends StatelessWidget {
  final Map<String, dynamic>? detailTransaksi;

  const TransaksiBerhasilScreen({super.key, this.detailTransaksi});

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatNumber(dynamic value) {
    final number = _asDouble(value).round();
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _materialName(dynamic wasteType) {
    if (wasteType is Map) {
      return (wasteType['name'] ?? 'Material').toString();
    }
    return wasteType?.toString() ?? 'Material';
  }

  List<Map<String, dynamic>> _readItems(Map<String, dynamic> data) {
    final raw = data['items'] is List
        ? data['items'] as List
        : data['wasteTransactions'] is List
            ? data['wasteTransactions'] as List
            : <dynamic>[];

    return raw.whereType<Map>().map((item) {
      final map = _asMap(item);
      return <String, dynamic>{
        'wasteType': _materialName(map['wasteType']),
        'weight': map['weight'] ?? 0,
        'totalPrice': map['totalPrice'] ?? map['amount'] ?? 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final root = _asMap(detailTransaksi);
    final data = root['data'] is Map ? _asMap(root['data']) : root;
    final items = _readItems(data);
    final earned = data['earned'] ?? data['totalAmount'] ?? 0;
    final balance = data['balance'];
    final sessionId = (data['sessionId'] ?? '-').toString();
    final machineName =
        (data['machineName'] ?? 'Smart Container EcoCash').toString();
    final machineCode = (data['machineCode'] ?? '').toString();
    final totalWeight = data['totalWeight'] != null
        ? _asDouble(data['totalWeight'])
        : items.fold<double>(
            0,
            (total, item) => total + _asDouble(item['weight']),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Pakai Column + Transform untuk kartu yang tingginya dinamis.
                    // Tidak menggunakan Positioned + SizedBox(height: 520),
                    // sehingga rincian transaksi panjang tidak terpotong.
                    Stack(
                      children: [
                        _buildHeader(),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 130,
                            left: 20,
                            right: 20,
                          ),
                          child: _buildSuccessCard(
                            items: items,
                            earned: earned,
                            balance: balance,
                            sessionId: sessionId,
                            totalWeight: totalWeight,
                            machineName: machineName,
                            machineCode: machineCode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const AppFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomActions(context),
      ),
    );
  }

  Widget _buildHeader() {
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
      padding: const EdgeInsets.only(top: 48, left: 20, right: 20),
      alignment: Alignment.topLeft,
      child: const Text(
        'Bukti Setor Sampah',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSuccessCard({
    required List<Map<String, dynamic>> items,
    required dynamic earned,
    required dynamic balance,
    required String sessionId,
    required double totalWeight,
    required String machineName,
    required String machineCode,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Transaksi Berhasil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Setoran sampah berhasil dikonfirmasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Hasil Setoran',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+Rp ${_formatNumber(earned)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Saldo Dompet Saat Ini: Rp ${_formatNumber(balance)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF388E3C),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi: $machineName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID Sesi: #$sessionId',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (machineCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Kode Mesin: $machineCode',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
                const Divider(height: 24),
                if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Rincian sampah tidak tersedia.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.recycling,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item['wasteType']} (${item['weight']} kg)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rp ${_formatNumber(item['totalPrice'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Total Muatan Bersih',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Text(
                      '${totalWeight.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Kembali ke Beranda',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanPage()),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Setor Sampah Lagi',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
