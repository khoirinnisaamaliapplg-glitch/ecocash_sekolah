import 'dart:convert';

import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class IsiSaldoPage extends StatefulWidget {
  const IsiSaldoPage({super.key});

  @override
  State<IsiSaldoPage> createState() => _IsiSaldoPageState();
}

class _IsiSaldoPageState extends State<IsiSaldoPage>
    with WidgetsBindingObserver {
  // ============================================================
  // STATE
  // ============================================================

  bool _isLoadingWallet = true;
  bool _isSubmitting = false;
  bool _isCheckingStatus = false;

  String _namaAkun = '-';
  double _balance = 0;

  int? _lastTopUpId;

  final TextEditingController _amountController = TextEditingController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _fetchWalletData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _amountController.dispose();

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed &&
        _lastTopUpId != null &&
        !_isSubmitting &&
        !_isCheckingStatus) {
      _checkTopUpStatus(_lastTopUpId!);
    }
  }

  // ============================================================
  // EXTRACT RESPONSE
  // ============================================================

  Map<String, dynamic> _extractDataMap(dynamic responseData) {
    if (responseData is! Map) {
      return {};
    }

    final Map<String, dynamic> responseMap = Map<String, dynamic>.from(
      responseData,
    );

    final dynamic data = responseMap['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return responseMap;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // USER NAME
  // ============================================================

  /// SAMA DENGAN ECOCASH INDONESIA
  ///
  /// Prioritas:
  /// 1. name dari GET /users/me
  /// 2. username
  /// 3. User
  String _getUserName(Map<String, dynamic> data) {
    final String name = data['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final String username = data['username']?.toString().trim() ?? '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'User';
  }

  // ============================================================
  // NUMBER PARSER
  // ============================================================

  double _parseNumber(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _getErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

      if (map['message'] != null) {
        return map['message'].toString();
      }

      if (map['error'] != null) {
        return map['error'].toString();
      }
    }

    return 'Terjadi kesalahan pada server.';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // FETCH PROFILE + WALLET
  // ============================================================

  /// LOGIKA SAMA DENGAN ECOCASH INDONESIA
  ///
  /// Nama:
  /// GET /users/me
  ///
  /// Saldo:
  /// GET /wallets/me
  Future<void> _fetchWalletData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingWallet = true;
        });
      }

      // ========================================================
      // REQUEST PROFILE + WALLET BERSAMAAN
      // ========================================================

      final List<http.Response> responses = await Future.wait<http.Response>([
        // PROFILE
        http.get(
          Uri.parse(ApiConfig.getUserProfile),
          headers: ApiConfig.headers,
        ),

        // WALLET
        http.get(Uri.parse(ApiConfig.getMyWallet), headers: ApiConfig.headers),
      ]);

      final http.Response profileResponse = responses[0];

      final http.Response walletResponse = responses[1];

      // ========================================================
      // DEBUG
      // ========================================================

      debugPrint('');
      debugPrint('========================================');
      debugPrint('ISI SALDO ECOCASH SEKOLAH');
      debugPrint('PROFILE STATUS : ${profileResponse.statusCode}');
      debugPrint('PROFILE BODY   : ${profileResponse.body}');
      debugPrint('WALLET STATUS  : ${walletResponse.statusCode}');
      debugPrint('WALLET BODY    : ${walletResponse.body}');
      debugPrint('========================================');
      debugPrint('');

      // ========================================================
      // PROFILE RESPONSE
      // ========================================================

      if (profileResponse.statusCode != 200) {
        throw Exception(
          'Gagal memuat profil '
          '(${profileResponse.statusCode})',
        );
      }

      // ========================================================
      // WALLET RESPONSE
      // ========================================================

      if (walletResponse.statusCode != 200) {
        throw Exception(
          'Gagal memuat wallet '
          '(${walletResponse.statusCode})',
        );
      }

      // ========================================================
      // DECODE JSON
      // ========================================================

      final dynamic decodedProfile = jsonDecode(profileResponse.body);

      final dynamic decodedWallet = jsonDecode(walletResponse.body);

      // ========================================================
      // EXTRACT DATA
      // ========================================================

      final Map<String, dynamic> profileData = _extractDataMap(decodedProfile);

      final Map<String, dynamic> walletData = _extractDataMap(decodedWallet);

      debugPrint('PROFILE DATA : $profileData');

      debugPrint('WALLET DATA  : $walletData');

      // ========================================================
      // GET NAME
      // ========================================================

      final String namaAkun = _getUserName(profileData);

      // ========================================================
      // GET BALANCE
      // ========================================================

      final dynamic balanceValue = walletData['balance'] ?? 0;

      final double balance = _parseNumber(balanceValue);

      debugPrint('');
      debugPrint('NAMA AKUN : $namaAkun');
      debugPrint('BALANCE   : $balance');
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _namaAkun = namaAkun;
        _balance = balance;
        _isLoadingWallet = false;
      });
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('FETCH WALLET ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _isLoadingWallet = false;
      });

      _showMessage('Gagal mengambil data: $e', error: true);
    }
  }

  // ============================================================
  // CREATE TOP UP
  // ============================================================

  Future<void> _createTopUp() async {
    FocusScope.of(context).unfocus();

    final String rawAmount = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final int? amount = int.tryParse(rawAmount);

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (amount == null || amount <= 0) {
      _showMessage('Masukkan nominal top up yang valid.', error: true);

      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });

      // ========================================================
      // POST /wallets/topup
      // ========================================================

      final http.Response response = await http.post(
        Uri.parse(ApiConfig.createTopUp),
        headers: ApiConfig.headers,
        body: jsonEncode({'amount': amount}),
      );

      debugPrint('');
      debugPrint('========================================');
      debugPrint('CREATE TOP UP');
      debugPrint('STATUS : ${response.statusCode}');
      debugPrint('BODY   : ${response.body}');
      debugPrint('========================================');
      debugPrint('');

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Response server tidak valid.');
      }

      // ========================================================
      // CHECK RESPONSE
      // ========================================================

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_getErrorMessage(decoded));
      }

      final Map<String, dynamic> data = _extractDataMap(decoded);

      // ========================================================
      // TOP UP ID
      // ========================================================

      final dynamic idValue = data['id'];

      if (idValue == null) {
        throw Exception('ID top up tidak ditemukan.');
      }

      final int? topUpId = int.tryParse(idValue.toString());

      if (topUpId == null) {
        throw Exception('ID top up tidak valid.');
      }

      _lastTopUpId = topUpId;

      // ========================================================
      // MODE
      // ========================================================

      final String mode = data['mode']?.toString().trim() ?? '';

      debugPrint('TOPUP ID   : $topUpId');

      debugPrint('TOPUP MODE : $mode');

      // ========================================================
      // LOCAL MOCK
      // ========================================================

      if (mode == 'local-mock') {
        await _mockPayTopUp(topUpId);

        return;
      }

      // ========================================================
      // MIDTRANS
      // ========================================================

      final String redirectUrl = data['redirectUrl']?.toString().trim() ?? '';

      if (redirectUrl.isEmpty) {
        throw Exception('URL pembayaran Midtrans tidak ditemukan.');
      }

      final Uri paymentUri = Uri.parse(redirectUrl);

      // ========================================================
      // OPEN PAYMENT
      // ========================================================

      /*
       * Secara logika sama dengan EcoCash Indonesia.
       *
       * Saya tidak memakai LaunchMode.externalApplication
       * karena sebelumnya bagian tersebut error
       * pada project EcoCash Sekolah Anda.
       */

      final bool launched = await launchUrl(paymentUri);

      if (!launched) {
        throw Exception('Tidak dapat membuka halaman Midtrans.');
      }

      _showMessage('Silakan selesaikan pembayaran.');
    } catch (e, stackTrace) {
      debugPrint('CREATE TOPUP ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Top up gagal: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // MOCK PAYMENT
  // ============================================================

  Future<void> _mockPayTopUp(int topUpId) async {
    try {
      final http.Response response = await http.post(
        Uri.parse(ApiConfig.mockPayTopUp(topUpId)),
        headers: ApiConfig.headers,
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Response server tidak valid.');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_getErrorMessage(decoded));
      }

      _showMessage('Top up berhasil.');

      _amountController.clear();

      _lastTopUpId = null;

      // ========================================================
      // REFRESH SALDO
      // ========================================================

      await _fetchWalletData();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showMessage('Mock payment gagal: $e', error: true);
    }
  }

  // ============================================================
  // CHECK PAYMENT STATUS
  // ============================================================

  Future<void> _checkTopUpStatus(int topUpId) async {
    if (_isCheckingStatus) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isCheckingStatus = true;
        });
      }

      final http.Response response = await http.post(
        Uri.parse(ApiConfig.checkTopUpStatus(topUpId)),
        headers: ApiConfig.headers,
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Response server tidak valid.');
      }

      if (response.statusCode != 200) {
        throw Exception(_getErrorMessage(decoded));
      }

      final Map<String, dynamic> result = _extractDataMap(decoded);

      final Map<String, dynamic> topUp = _toMap(result['topup']);

      final String status =
          topUp['status']?.toString().toUpperCase().trim() ?? '';

      final String gatewayStatus =
          result['gatewayStatus']?.toString().toLowerCase().trim() ?? '';

      debugPrint('');
      debugPrint('================================');
      debugPrint('TOP UP ID       : $topUpId');
      debugPrint('TOP UP STATUS   : $status');
      debugPrint('MIDTRANS STATUS : $gatewayStatus');
      debugPrint('================================');
      debugPrint('');

      // ========================================================
      // COMPLETED
      // ========================================================

      if (status == 'COMPLETED') {
        _showMessage(
          'Pembayaran berhasil. '
          'Saldo telah ditambahkan.',
        );

        _lastTopUpId = null;

        _amountController.clear();

        await _fetchWalletData();

        if (mounted) {
          setState(() {});
        }

        return;
      }

      // ========================================================
      // FAILED
      // ========================================================

      if (status == 'FAILED') {
        _showMessage('Pembayaran gagal atau dibatalkan.', error: true);

        _lastTopUpId = null;

        return;
      }

      // ========================================================
      // PENDING
      // ========================================================

      _showMessage('Pembayaran masih menunggu konfirmasi.');
    } catch (e) {
      _showMessage('Gagal mengecek pembayaran: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: RefreshIndicator(
        onRefresh: _fetchWalletData,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          child: Column(
            children: [
              _buildHeader(context),

              const SizedBox(height: 105),

              _buildTopUpForm(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,

      children: [
        Container(
          height: 280,

          width: double.infinity,

          decoration: const BoxDecoration(
            color: Colors.blue,

            // ==================================================
            // TETAP TAMPILAN ECOCASH SEKOLAH
            // ==================================================
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
                onPressed: () {
                  Navigator.pop(context);
                },

                icon: const Icon(Icons.arrow_back, color: Colors.white),

                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
              ),

              const SizedBox(width: 15),

              const Padding(
                padding: EdgeInsets.only(top: 8),

                child: Text(
                  'Isi Saldo',

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 24,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Positioned(top: 150, left: 20, right: 20, child: _buildBalanceCard()),
      ],
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard() {
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

      child: _isLoadingWallet
          ? const SizedBox(
              height: 130,

              child: Center(child: CircularProgressIndicator()),
            )
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

                const SizedBox(height: 5),

                // ===========================================
                // NAMA DARI GET /users/me
                // ===========================================
                Text(
                  _namaAkun,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

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

                    Expanded(
                      child: Text(
                        _currencyFormatter.format(_balance),

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 27,

                          fontWeight: FontWeight.bold,

                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ============================================================
  // TOP UP FORM
  // ============================================================

  Widget _buildTopUpForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Nominal Isi Saldo',

            style: TextStyle(
              fontSize: 18,

              fontWeight: FontWeight.bold,

              color: Color(0xFF2D3E50),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: _amountController,

            keyboardType: TextInputType.number,

            inputFormatters: [FilteringTextInputFormatter.digitsOnly],

            decoration: InputDecoration(
              prefixText: 'Rp ',

              hintText: '0',

              filled: true,

              fillColor: const Color(0xFFF5F5F5),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,

                vertical: 18,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),

            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),

            onChanged: (_) {
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          const Text(
            'Pilih Nominal',

            style: TextStyle(
              fontSize: 14,

              color: Colors.grey,

              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,

            runSpacing: 10,

            children: [
              _buildNominalButton(10000),
              _buildNominalButton(20000),
              _buildNominalButton(50000),
              _buildNominalButton(100000),
              _buildNominalButton(200000),
              _buildNominalButton(500000),
            ],
          ),

          if (_lastTopUpId != null) ...[
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,

              height: 48,

              child: OutlinedButton.icon(
                onPressed: _isCheckingStatus
                    ? null
                    : () {
                        _checkTopUpStatus(_lastTopUpId!);
                      },

                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 18,

                        height: 18,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),

                label: Text(
                  _isCheckingStatus
                      ? 'Memeriksa Pembayaran...'
                      : 'Cek Status Pembayaran',
                ),

                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // NOMINAL BUTTON
  // ============================================================

  Widget _buildNominalButton(int amount) {
    final String currentAmount = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final bool selected = currentAmount == amount.toString();

    return ChoiceChip(
      selected: selected,

      label: Text(_currencyFormatter.format(amount)),

      onSelected: (_) {
        setState(() {
          _amountController.text = amount.toString();

          _amountController.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountController.text.length),
          );
        });
      },
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    final String rawAmount = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final int amount = int.tryParse(rawAmount) ?? 0;

    final bool enabled = !_isSubmitting && !_isLoadingWallet && amount > 0;

    return SafeArea(
      top: false,

      child: Container(
        color: Colors.white,

        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),

        child: SizedBox(
          width: double.infinity,

          height: 55,

          child: ElevatedButton(
            onPressed: enabled ? _createTopUp : null,

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,

              disabledBackgroundColor: const Color(0xFFD3D3D3),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),

              elevation: 0,
            ),

            child: _isSubmitting
                ? const SizedBox(
                    width: 24,

                    height: 24,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Konfirmasi',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 18,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
