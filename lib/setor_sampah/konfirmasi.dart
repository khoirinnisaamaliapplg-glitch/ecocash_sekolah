import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/core/session_socket.dart';
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

  /// Kanal live `/sessions`. Polling hanya dipakai sebagai fallback.
  SessionSocket? _sessionSocket;
  bool _isSocketConnected = false;

  /// Layar sudah menutup diri karena sesi dibatalkan (mencegah pop ganda).
  bool _sessionClosed = false;

  /// Struk sudah dibuka (mencegah dua navigasi dari dua kanal pembayaran).
  bool _receiptShown = false;

  /// Sesi sudah dibayar, apa pun kanalnya. Dipakai untuk teks tombol.
  bool _kioskSettled = false;

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
    _connectSocket();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSocket?.disconnect();
    super.dispose();
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  /// Satu baris item dalam bentuk yang dipakai layar ini (angka = String),
  /// baik dari snapshot HTTP maupun dari event `session:item`.
  Map<String, dynamic> _toDisplayItem(Map<String, dynamic> rawItem) {
    final dynamic waste = rawItem['wasteType'];

    final String typeName = waste is Map
        ? (waste['name'] ?? 'Material').toString()
        : (waste ?? 'Material').toString();

    return {
      'id': int.tryParse('${rawItem['id'] ?? ''}'),
      'wasteType': typeName,
      'weight': (rawItem['weight'] ?? 0).toString(),
      'totalPrice': (rawItem['totalPrice'] ?? 0).toString(),
      'pricePerKg': (rawItem['pricePerKg'] ?? 0).toString(),
    };
  }

  /// Snapshot dari server: data awal, setelah reconnect, dan fallback polling.
  void _applySessionData(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString().trim().toUpperCase();

    final List<dynamic> rawItems = data['items'] is List
        ? data['items'] as List
        : <dynamic>[];

    final Map<String, dynamic> summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};

    final dynamic machine = data['machine'];

    final List<Map<String, dynamic>> items = [];

    for (final dynamic rawItem in rawItems) {
      if (rawItem is Map) {
        items.add(_toDisplayItem(Map<String, dynamic>.from(rawItem)));
      }
    }

    if (!mounted) return;

    /*
     * Gabungkan, jangan timpa: event `session:item` bisa tiba lebih dulu
     * daripada response snapshot (snapshot dibaca sedikit sebelum item itu
     * di-commit), dan item tersebut tidak boleh hilang dari layar.
     */
    final List<Map<String, dynamic>> merged = List<Map<String, dynamic>>.from(
      items,
    );

    for (final Map<String, dynamic> existing in _wasteItems) {
      final Object? id = existing['id'];

      if (id != null && !merged.any((item) => item['id'] == id)) {
        merged.add(existing);
      }
    }

    setState(() {
      _wasteItems = merged;

      // Total selalu sama dengan jumlah baris yang terlihat.
      if (merged.isNotEmpty) {
        double weight = 0;

        double price = 0;

        for (final Map<String, dynamic> item in merged) {
          weight += _number(item['weight']);

          price += _number(item['totalPrice']);
        }

        _currentTotalWeight = weight;

        _currentTotalPrice = price;
      } else {
        _currentTotalWeight = _number(summary['currentWeight']);

        _currentTotalPrice = _number(summary['totalPrice']);
      }

      if (machine is Map) {
        _machineName = machine['name']?.toString();

        _machineCode = machine['machineCode']?.toString();
      }
    });

    // Total sudah dihitung di atas, jadi summary tidak dipakai lagi.
    _applyStatus(status, <String, dynamic>{});
  }

  /// Mengubah status sesi menjadi teks di layar. [summary] boleh kosong
  /// (event `session:state` saat konfirmasi tidak membawa summary).
  ///
  /// [earned] dan [balance] hanya ada pada event `session:state` yang dikirim
  /// setelah pembayaran; keduanya dipakai untuk struk bila mesin yang
  /// mencairkan sesi lebih dulu.
  void _applyStatus(
    String status,
    Map<String, dynamic> summary, {
    dynamic earned,
    dynamic balance,
  }) {
    if (!mounted) return;

    final bool wasReady = _isReadyToConfirm;

    setState(() {
      if (summary['currentWeight'] != null) {
        _currentTotalWeight = _number(summary['currentWeight']);
      }

      if (summary['totalPrice'] != null) {
        _currentTotalPrice = _number(summary['totalPrice']);
      }

      _isReadyToConfirm = status == 'WAITING_CONFIRMATION';

      if (_isReadyToConfirm) {
        _statusMesin =
            'Mesin selesai menimbang! Silakan konfirmasi untuk menerima saldo.';
      } else if (status == 'ACTIVE') {
        _statusMesin = _wasteItems.isEmpty
            ? 'Pintu mesin terbuka. Masukkan botol/sampah Anda...'
            : 'Sedang menimbang muatan sampah...';
      } else if (status == 'COMPLETED') {
        _kioskSettled = true;
        _statusMesin =
            'Sesi selesai — saldo sudah ditambahkan ke dompet Anda.';
      } else if (status == 'CANCELLED' ||
          status == 'FAILED' ||
          status == 'EXPIRED') {
        _statusMesin = 'Sesi setoran dibatalkan atau gagal.';
      }
    });

    if (!wasReady && _isReadyToConfirm) {
      HapticFeedback.heavyImpact();
    }

    if (['COMPLETED', 'CANCELLED', 'FAILED', 'EXPIRED'].contains(status)) {
      _timer?.cancel();
    }

    /*
     * COMPLETED datang dari dua arah: tombol Konfirmasi di HP ini, atau mesin
     * yang mencairkan lebih dulu (satu tombol di layar mesin). Keduanya
     * berakhir di struk yang sama - `_openReceipt` mengabaikan panggilan kedua,
     * jadi pengguna tidak pernah melihat layar "menunggu mesin" yang menggantung.
     */
    if (status == 'COMPLETED') {
      _openReceipt(earned: earned, balance: balance);
      return;
    }

    if (['CANCELLED', 'FAILED', 'EXPIRED'].contains(status)) {
      _handleSessionClosed(status);
    }
  }

  /// Sesi ditutup oleh mesin (atau pembersihan otomatis di server).
  ///
  /// `CANCELLED` berarti **tidak ada setoran sama sekali**: `/complete` memakai
  /// `currentWeight > 0 ? WAITING_CONFIRMATION : CANCELLED`, dan pembersihan
  /// sesi memakai aturan yang sama. Jadi kalau tidak ada sampah yang masuk,
  /// layar ini tidak ada gunanya lagi - tutup sendiri dan beri tahu pengguna.
  void _handleSessionClosed(String status) {
    if (_sessionClosed || !mounted) return;

    // Struk sudah ditangani oleh _handleConfirm.
    if (status == 'COMPLETED') return;

    // Ada catatan setoran: biarkan pengguna melihatnya, jangan ditutup.
    if (_wasteItems.isNotEmpty) return;

    _sessionClosed = true;

    _sessionSocket?.disconnect();

    // Jeda singkat supaya perubahan status di layar sempat terbaca.
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      /*
       * Lookup dilakukan di dalam callback: kalau sesi sudah CANCELLED pada
       * snapshot awal, method ini ikut berjalan saat initState, dan
       * ScaffoldMessenger.of() belum boleh dipanggil di sana.
       */
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      final NavigatorState navigator = Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Sesi dibatalkan karena tidak ada sampah yang masuk. '
              'Silakan pindai QR di mesin untuk mencoba lagi.',
            ),
          ),
        );
    });
  }

  // ============================================================
  // LIVE CHANNEL (/sessions)
  // ============================================================

  void _connectSocket() {
    _sessionSocket = SessionSocket(
      onItem: _handleLiveItem,
      onState: _handleLiveState,
      onConnectionChanged: (bool connected) {
        if (mounted) {
          setState(() => _isSocketConnected = connected);
        } else {
          _isSocketConnected = connected;
        }

        /*
         * Event yang dipancarkan saat socket mati tidak dikirim ulang,
         * jadi setiap connect/reconnect diikuti satu snapshot HTTP.
         */
        if (connected) {
          _refreshSession();
        }
      },
    );

    _sessionSocket!.connect();
  }

  /// `session:item` — satu setoran baru dari mesin, tampil tanpa polling.
  void _handleLiveItem(Map<String, dynamic> event) {
    if (!mounted) return;

    final int? sessionId = int.tryParse('${event['sessionId'] ?? ''}');

    if (sessionId != null && sessionId != widget.sessionId) return;

    if (event['item'] is! Map) return;

    final Map<String, dynamic> item = _toDisplayItem(
      Map<String, dynamic>.from(event['item'] as Map),
    );

    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      _wasteItems,
    );

    // Idempoten: event yang sama tidak boleh menambah baris dua kali.
    final Object? itemId = item['id'];

    if (itemId != null && items.any((existing) => existing['id'] == itemId)) {
      return;
    }

    items.add(item);

    setState(() {
      _wasteItems = items;

      _currentTotalWeight += _number(item['weight']);

      _currentTotalPrice += _number(item['totalPrice']);

      _statusMesin = 'Sedang menimbang muatan sampah...';
    });

    HapticFeedback.mediumImpact();
  }

  /// `session:state` — WAITING_CONFIRMATION / COMPLETED / CANCELLED.
  void _handleLiveState(Map<String, dynamic> event) {
    if (!mounted) return;

    final int? sessionId = int.tryParse('${event['sessionId'] ?? ''}');

    if (sessionId != null && sessionId != widget.sessionId) return;

    final String status = (event['status'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (status.isEmpty) return;

    final Map<String, dynamic> summary = event['summary'] is Map
        ? Map<String, dynamic>.from(event['summary'] as Map)
        : <String, dynamic>{};

    _applyStatus(
      status,
      summary,
      earned: event['earned'],
      balance: event['balance'],
    );
  }

  // Poll sesi ini saja; /current bisa menunjuk sesi lain atau data kosong.
  //
  // Ini hanya fallback: selama socket tersambung, item dan status datang
  // lewat push sehingga tidak perlu ada request tiap 2 detik.
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
      if (_isSocketConnected) return;
      _refreshSession();
    });
  }

  Future<void> _refreshSession() async {
    if (_isPolling || !mounted) return;
    _isPolling = true;
    try {
      // Ambil detail menggunakan ID sesi hasil scan supaya tidak tertukar.
      final dynamic payload = await ApiClient.get(
        ApiConfig.getSessionDetail(widget.sessionId.toString()),
        timeout: const Duration(seconds: 12),
      );

      if (payload is! Map) return;

      final data = Map<String, dynamic>.from(payload);

      final responseId = int.tryParse(
        (data['id'] ?? data['sessionId'] ?? '').toString(),
      );
      if (responseId != null && responseId != widget.sessionId) return;
      _applySessionData(data);
    } catch (e) {
      debugPrint('Polling detail sesi gagal: $e');

      if (e is ApiException && e.isUnauthorized && mounted) {
        setState(
          () => _statusMesin = 'Sesi login berakhir. Silakan login kembali.',
        );
        _timer?.cancel();
      }
    } finally {
      _isPolling = false;
    }
  }

  // Langkah 5: Pengguna Konfirmasi & Menerima Pembayaran (POST /machine-sessions/:id/confirm)
  Future<void> _handleConfirm() async {
    if (!_isReadyToConfirm || _isLoading || _isTimedOut) return;
    setState(() => _isLoading = true);

    try {
      final dynamic payload = await ApiClient.post(
        ApiConfig.confirmSession(widget.sessionId.toString()),
      );

      _timer?.cancel();

      // ApiClient sudah melempar ApiException untuk status non-2xx,
      // jadi blok ini hanya berjalan saat konfirmasi berhasil.
      final Map<String, dynamic> confirmData = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};

      _openReceipt(
        earned: confirmData['earned'],
        balance: confirmData['balance'],
      );
    } catch (e) {
      /*
       * Balapan: mesin mencairkan sesi tepat saat tombol di HP ditekan. Tombol
       * ini hanya pintu cadangan, jadi hasilnya tetap struk - bukan error.
       */
      if (_isAlreadySettled(e)) {
        _openReceipt(earned: _currentTotalPrice);
        return;
      }

      _showSnackBar(
        e is ApiException ? e.message : 'Koneksi bermasalah: $e',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sesi sudah dibayar di kanal lain (mesin) atau sudah dibatalkan. Keduanya
  /// bukan kesalahan pengguna, jadi layar ini tidak perlu menampilkan error.
  bool _isAlreadySettled(Object error) {
    if (error is! ApiException) return false;

    if (error.statusCode == 409 || error.code == 'SESSION_NOT_CONFIRMABLE') {
      return true;
    }

    final String message = error.message.toLowerCase();

    return message.contains('already settled') ||
        message.contains('not waiting for confirmation');
  }

  /// Struk akhir, dipakai kedua kanal pembayaran:
  ///
  ///   - pengguna menekan "Konfirmasi & Terima Saldo" (POST /confirm), atau
  ///   - mesin yang mencairkan sesi lebih dulu lewat satu tombol di layarnya,
  ///     sehingga HP tidak perlu melakukan apa pun (`session:state` COMPLETED).
  ///
  /// [balance] boleh null: snapshot HTTP tidak membawa saldo dompet, dan struk
  /// hanya menampilkannya bila nilainya diketahui.
  void _openReceipt({dynamic earned, dynamic balance}) {
    if (_receiptShown || !mounted) return;

    _receiptShown = true;
    _timer?.cancel();
    _sessionSocket?.disconnect();

    final String earnedText = (earned ?? _currentTotalPrice).toString();

    final Map<String, dynamic> receipt = {
      'sessionId': widget.sessionId.toString(),
      'earned': earnedText,
      'totalAmount': earnedText,
      'totalWeight': _currentTotalWeight.toStringAsFixed(2),
      'machineName': _machineName ?? 'Smart Container EcoCash',
      'machineCode': _machineCode ?? '',
      'items': _wasteItems,
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

    if (balance != null) {
      receipt['balance'] = balance.toString();
    }

    /*
     * Jeda singkat supaya status "selesai" di layar setor sempat terbaca, dan
     * supaya navigasi tidak pernah terjadi di tengah initState.
     */
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TransaksiBerhasilScreen(
            detailTransaksi: {'data': receipt},
          ),
        ),
        (route) => route.isFirst,
      );
    });
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
          actions: [
            // Penanda kanal live: "Live" = push dari socket, "Sync" = polling.
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSocketConnected ? Icons.bolt : Icons.sync,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSocketConnected ? 'Live' : 'Sync',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                        : _kioskSettled
                        ? "Saldo sudah diterima ✓"
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
