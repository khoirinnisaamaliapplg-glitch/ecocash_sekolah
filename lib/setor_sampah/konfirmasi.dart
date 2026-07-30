import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk HapticFeedback
import 'package:http/http.dart' as http;
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/transaksi.dart';

class SetorSampahScreen extends StatefulWidget {
  final int? sessionId;

  const SetorSampahScreen({super.key, this.sessionId});

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  bool _isLoading = false;
  bool _isReadyToConfirm = false;
  String _statusMesin = "Menunggu mesin menimbang sampah...";
  Timer? _timer;

  // Live waste items fetched from the session detail endpoint
  List<Map<String, dynamic>> _wasteItems = [];
  double _currentTotalWeight = 0;
  double _currentTotalPrice = 0;

  // Timeout setelah 5 menit agar tidak terus-menerus polling
  int _secondsElapsed = 0;
  final int _maxSeconds = 300;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      _startPolling();
    } else {
      _statusMesin = "ID Sesi tidak ditemukan.";
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _secondsElapsed += 2;

      if (!mounted || _secondsElapsed >= _maxSeconds) {
        timer.cancel();
        if (mounted && !_isReadyToConfirm) {
          setState(
            () => _statusMesin = "Waktu tunggu habis. Silakan scan ulang.",
          );
        }
        return;
      }

      try {
        final response = await http.get(
          Uri.parse(ApiConfig.getSessionDetail(widget.sessionId!.toString())),
          headers: ApiConfig.headers,
        );

        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          String status = data['status']?.toString().trim().toUpperCase() ?? "";

          // Extract waste items from the session detail
          final List items = data['items'] ?? [];
          final double totalWeight =
              (data['summary']?['currentWeight'] ?? 0).toDouble();
          final double totalPrice =
              (data['summary']?['totalPrice'] ?? 0).toDouble();

          setState(() {
            _wasteItems = items.map((item) => {
              'wasteType': item['wasteType'] ?? 'Sampah',
              'weight': (item['weight'] ?? 0).toString(),
              'totalPrice': (item['totalPrice'] ?? 0).toString(),
            }).toList();
            _currentTotalWeight = totalWeight;
            _currentTotalPrice = totalPrice;
          });

          if (status == 'WAITING_CONFIRMATION') {
            timer.cancel();
            HapticFeedback.heavyImpact();
            setState(() {
              _statusMesin = "Selesai! Silakan konfirmasi untuk proses data.";
              _isReadyToConfirm = true;
            });
          } else if (status == 'CANCELLED' || status == 'FAILED') {
            timer.cancel();
            setState(() => _statusMesin = "Transaksi gagal/dibatalkan.");
          }
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm || widget.sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Confirm the session (credits wallet)
      final confirmResponse = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId!.toString())),
        headers: ApiConfig.headers,
      );

      if (confirmResponse.statusCode != 200) {
        _showSnackBar("Gagal konfirmasi: ${confirmResponse.statusCode}", Colors.red);
        return;
      }

      final confirmData = jsonDecode(confirmResponse.body);
      // confirmData.data = { sessionId, status, earned, balance }

      // Step 2: Fetch session detail to get waste items
      final detailResponse = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(widget.sessionId!.toString())),
        headers: ApiConfig.headers,
      );

      if (!mounted) return;

      Map<String, dynamic> successData = {};

      if (detailResponse.statusCode == 200) {
        final detailData = jsonDecode(detailResponse.body);
        // detailData = { id, status, machine, summary: {currentWeight, totalPrice}, items: [...] }

        successData = {
          'sessionId': widget.sessionId.toString(),
          'totalAmount': detailData['summary']?['totalPrice']?.toString() ?? '0',
          'earned': confirmData['data']?['earned']?.toString() ?? '0',
          'balance': confirmData['data']?['balance']?.toString() ?? '0',
          'wasteTransactions': (detailData['items'] as List?)?.map((item) => {
            'wasteType': {'name': item['wasteType'] ?? 'Sampah'},
            'weight': (item['weight'] ?? 0).toString(),
            'amount': (item['totalPrice'] ?? 0).toString(),
          }).toList() ?? [],
        };
      } else {
        // Fallback if detail fetch fails
        successData = {
          'sessionId': widget.sessionId.toString(),
          'totalAmount': confirmData['data']?['earned']?.toString() ?? '0',
          'earned': confirmData['data']?['earned']?.toString() ?? '0',
          'balance': confirmData['data']?['balance']?.toString() ?? '0',
          'wasteTransactions': [],
        };
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransaksiBerhasilScreen(detailTransaksi: {'data': successData}),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      _showSnackBar("Koneksi bermasalah: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => _timer?.cancel(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4CAF50),
          title: const Text(
            'Setor Sampah',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // --- Status Card ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    if (!_isReadyToConfirm) ...[
                      const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                      const SizedBox(height: 16),
                    ] else ...[
                      const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50), size: 48),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _statusMesin,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isReadyToConfirm
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- Live Waste Items List ---
              if (_wasteItems.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.recycling,
                              color: Color(0xFF4CAF50), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Sampah yang Disetor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_wasteItems.length} item',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF388E3C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Waste items list
                      ..._wasteItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final wasteType = item['wasteType'] ?? 'Sampah';
                        final weight = item['weight'] ?? '0';
                        final price = item['totalPrice'] ?? '0';
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: index < _wasteItems.length - 1 ? 12 : 0),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Color(0xFF4CAF50), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wasteType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$weight Kg',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rp $price',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF388E3C),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 24),

                      // Running total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Berat',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${_currentTotalWeight.toStringAsFixed(2)} Kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimasi Pendapatan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Rp ${_currentTotalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF388E3C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: (_isReadyToConfirm && !_isLoading)
                ? _handleConfirm
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _isReadyToConfirm
                        ? "Konfirmasi Transaksi"
                        : "Menunggu mesin...",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}
