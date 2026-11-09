import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/setor_sampah/transaksi.dart';
import 'package:ecocash_sekolah/app_footer.dart';

class SetorSampahScreen extends StatefulWidget {
  final int sessionId;
  final Map<String, dynamic>? initialSessionData;

  const SetorSampahScreen({
    super.key,
    required this.sessionId,
    this.initialSessionData,
  });

  @override
  State<SetorSampahScreen> createState() => _SetorSampahScreenState();
}

class _SetorSampahScreenState extends State<SetorSampahScreen> {
  bool _isLoading = false;
  bool _isReadyToConfirm = false;
  String _statusMesin = "Silakan masukkan botol/sampah Anda ke lubang mesin...";
  Timer? _timer;
  bool _isPolling = false;
  bool _isTimedOut = false;

  List<Map<String, dynamic>> _wasteItems = [];
  double _currentTotalWeight = 0.0;
  double _currentTotalPrice = 0.0;
  String? _machineName;
  String? _machineCode;

  int _secondsElapsed = 0;
  final int _maxSeconds = 600; // 10 menit batas waktu polling

  @override
  void initState() {
    super.initState();
    if (widget.initialSessionData != null) {
      _applySessionData(widget.initialSessionData!);
    }
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  // Data awal dari scan dan pembaruan status dari server.
  void _applySessionData(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toUpperCase();
    final rawItems = data['items'] is List
        ? data['items'] as List
        : <dynamic>[];
    final summary = data['summary'] is Map
        ? data['summary'] as Map
        : <dynamic, dynamic>{};
    final machine = data['machine'];

    final items = <Map<String, dynamic>>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final waste = rawItem['wasteType'];
      final typeName = waste is Map
          ? (waste['name'] ?? 'Material').toString()
          : (waste ?? 'Material').toString();
      items.add({
        'wasteType': typeName,
        'weight': (rawItem['weight'] ?? 0).toString(),
        'totalPrice': (rawItem['totalPrice'] ?? 0).toString(),
        'pricePerKg': (rawItem['pricePerKg'] ?? 0).toString(),
      });
    }

    if (!mounted) return;
    final wasReady = _isReadyToConfirm;
    setState(() {
      _wasteItems = items;
      _currentTotalWeight = _number(summary['currentWeight']);
      _currentTotalPrice = _number(summary['totalPrice']);
      if (machine is Map) {
        _machineName = machine['name']?.toString();
        _machineCode = machine['machineCode']?.toString();
      }
      _isReadyToConfirm = status == 'WAITING_CONFIRMATION';
      if (_isReadyToConfirm) {
        _statusMesin =
            'Mesin selesai menimbang! Silakan konfirmasi untuk menerima saldo.';
      } else if (status == 'ACTIVE') {
        _statusMesin = items.isEmpty
            ? 'Pintu mesin terbuka. Masukkan botol/sampah Anda...'
            : 'Sedang menimbang muatan sampah...';
      } else if (status == 'COMPLETED') {
        _statusMesin = 'Sesi telah selesai dikonfirmasi.';
      } else if (status == 'CANCELLED' || status == 'FAILED') {
        _statusMesin = 'Sesi setoran dibatalkan atau gagal.';
      }
    });
    if (!wasReady && _isReadyToConfirm) HapticFeedback.heavyImpact();
    if (['COMPLETED', 'CANCELLED', 'FAILED'].contains(status)) {
      _timer?.cancel();
    }
  }

  // Poll sesi ini saja; /current bisa menunjuk sesi lain atau data kosong.
  void _startPolling() {
    _timer?.cancel();
    _refreshSession();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _isLoading || _isPolling || _isTimedOut) return;
      _secondsElapsed += 2;
      if (_secondsElapsed >= _maxSeconds) {
        _timer?.cancel();
        if (mounted && !_isReadyToConfirm) {
          setState(() {
            _isTimedOut = true;
            _statusMesin = 'Waktu tunggu habis. Silakan periksa sesi mesin.';
          });
        }
        return;
      }
      _refreshSession();
    });
  }

  Future<void> _refreshSession() async {
    if (_isPolling || !mounted) return;
    _isPolling = true;
    try {
      // Ambil detail menggunakan ID sesi hasil scan supaya tidak tertukar.
      final response = await http
          .get(
            Uri.parse(ApiConfig.getSessionDetail(widget.sessionId.toString())),
            headers: ApiConfig.headers,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('DETAIL SESSION STATUS: ${response.statusCode}');
        if (response.statusCode == 401 && mounted) {
          setState(
            () => _statusMesin = 'Sesi login berakhir. Silakan login kembali.',
          );
          _timer?.cancel();
        }
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final dynamic candidate = decoded['data'] is Map
          ? decoded['data']
          : decoded;
      if (candidate is! Map) return;
      final data = Map<String, dynamic>.from(candidate);
      final responseId = int.tryParse(
        (data['id'] ?? data['sessionId'] ?? '').toString(),
      );
      if (responseId != null && responseId != widget.sessionId) return;
      _applySessionData(data);
    } catch (e) {
      debugPrint('Polling detail sesi gagal: $e');
    } finally {
      _isPolling = false;
    }
  }

  // Langkah 5: Pengguna Konfirmasi & Menerima Pembayaran (POST /machine-sessions/:id/confirm)
  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm || _isLoading || _isTimedOut) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.confirmSession(widget.sessionId.toString())),
        headers: ApiConfig.headers,
      );

      final decoded = jsonDecode(response.body);
      final body = decoded is Map ? decoded : <String, dynamic>{};

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          (body['success'] == true || body['data'] != null)) {
        _timer?.cancel();
        final confirmData = body['data'] is Map
            ? body['data'] as Map
            : <dynamic, dynamic>{};

        // Paket data bukti transaksi untuk TransaksiBerhasilScreen
        final Map<String, dynamic> successPayload = {
          'sessionId': widget.sessionId.toString(),
          'earned':
              confirmData['earned']?.toString() ??
              _currentTotalPrice.toStringAsFixed(0),
          'balance': confirmData['balance']?.toString() ?? '0',
          'totalWeight': _currentTotalWeight.toStringAsFixed(2),
          'machineName': _machineName ?? 'Smart Container EcoCash',
          'machineCode': _machineCode ?? '',
          'items': _wasteItems,
          'totalAmount':
              confirmData['earned']?.toString() ??
              _currentTotalPrice.toStringAsFixed(0),
          'wasteTransactions': _wasteItems
              .map(
                (item) => {
                  'wasteType': {'name': item['wasteType']},
                  'weight': item['weight'],
                  'amount': item['totalPrice'],
                },
              )
              .toList(),
        };

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TransaksiBerhasilScreen(
              detailTransaksi: {'data': successPayload},
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        final String errMsg =
            (body['message'] ?? 'Gagal melakukan konfirmasi sesi.').toString();
        _showSnackBar(errMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Koneksi bermasalah: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
          title: Text(
            _machineName != null ? 'Setor - $_machineName' : 'Setor Sampah',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Kartu Status Mesin
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!_isReadyToConfirm) ...[
                      const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                      const SizedBox(height: 16),
                    ] else ...[
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _statusMesin,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _isReadyToConfirm
                            ? Colors.green[800]
                            : Colors.black87,
                      ),
                    ),
                    if (_machineCode != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Kode Mesin: $_machineCode',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rincian Item yang Masuk
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.recycling,
                          color: Color(0xFF4CAF50),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sampah Terdeteksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_wasteItems.length} Item',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF388E3C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (_wasteItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'Belum ada sampah yang dimasukkan.\nMasukkan sampah satu per satu ke lubang mesin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._wasteItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['wasteType'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${item['weight']} kg',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rp ${item['totalPrice']}',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Timbangan',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          '${_currentTotalWeight.toStringAsFixed(2)} Kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
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
                          'Estimasi Bagi Hasil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rp ${_currentTotalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF388E3C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const AppFooter(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: (_isReadyToConfirm && !_isLoading && !_isTimedOut)
                ? _handleConfirm
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              disabledBackgroundColor: Colors.grey.shade400,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isReadyToConfirm
                        ? "Konfirmasi & Terima Saldo"
                        : "Menunggu Mesin Selesai...",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
