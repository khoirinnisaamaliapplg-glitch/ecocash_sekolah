import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/app_footer.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final Color primary = const Color(0xFF2196F3); // Tema biru EcoCash Sekolah
  static const double adminFee = 2500.0;

  bool _isLoadingWallet = true;
  bool _isSubmitting = false;
  double _balance = 0.0;

  String _selectedMethodType = 'BANK';
  String _selectedProvider = 'BCA';

  final List<String> _bankOptions = ['BCA', 'BRI', 'Mandiri', 'BNI'];
  final List<String> _ewalletOptions = ['GoPay', 'DANA', 'OVO', 'ShopeePay'];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletBalance() async {
    if (!mounted) return;
    setState(() => _isLoadingWallet = true);
    try {
      final data = await ApiClient.getMap(ApiConfig.getMyWallet);
      final rawBalance = data['balance'] ?? 0;

      if (!mounted) return;
      setState(() {
        _balance = (rawBalance is num)
            ? rawBalance.toDouble()
            : double.tryParse(rawBalance.toString()) ?? 0.0;
      });
    } on ApiException catch (e) {
      debugPrint('Gagal memuat saldo: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    FocusScope.of(context).unfocus();

    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double? amount = double.tryParse(rawAmount);

    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimal penarikan saldo adalah Rp 10.000"), backgroundColor: Colors.orange),
      );
      return;
    }

    // Biaya admin diambil dari acuan frontend; backend tetap sumber kebenaran.
    final double totalRequired = amount + adminFee;
    if (_balance < totalRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saldo tidak cukup. Dibutuhkan ${_currencyFormat.format(totalRequired)} (Termasuk admin Rp 2.500)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedMethodType == 'BANK' ? "Nomor rekening wajib diisi" : "Nomor e-wallet/HP wajib diisi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama pemilik rekening/akun wajib diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        "amount": amount,
        "bankName": _selectedProvider,
        "accountNumber": _accountNumberController.text.trim(),
        "accountHolderName": _accountHolderController.text.trim(),
      };

      final result = await ApiClient.post(
        "${ApiConfig.baseUrl}/wallets/withdraw",
        body: payload,
      );
      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};

      if (!mounted) return;
      final balanceAfter = data['balanceAfter'];
      final formattedBalance = balanceAfter != null
          ? _currencyFormat.format(
              num.tryParse(balanceAfter.toString()) ?? 0,
            )
          : 'Periksa saldo terbaru';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text("Permintaan Diterima"),
            ],
          ),
          content: Text(
            "Permintaan pencairan ${_currencyFormat.format(amount)} ke $_selectedProvider (${_accountNumberController.text.trim()}) diterima server dan sedang diproses.\n\nEstimasi biaya admin: ${_currencyFormat.format(adminFee)}\nSaldo setelah permintaan: $formattedBalance",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: () {
                Navigator.pop(ctx);
                _amountController.clear();
                _accountNumberController.clear();
                _accountHolderController.clear();
                _fetchWalletBalance();
              },
              child: const Text("Selesai", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kesalahan jaringan: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showTransactionHistoryDialog() {
    /*
     * Diambil sekali di sini, bukan di dalam `builder`. FutureBuilder yang
     * membuat future di dalam build akan menembak request baru setiap kali
     * sheet rebuild (scroll, setState, keyboard).
     */
    final Future<dynamic> historyFuture = ApiClient.get(
      ApiConfig.getMyWalletTransactions,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<dynamic>(
              future: historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Center(
                    child: Text(
                      error is ApiException
                          ? error.message
                          : "Gagal memuat mutasi dompet",
                    ),
                  );
                }

                final dynamic rawData = snapshot.data;
                final List items = rawData is List
                    ? rawData
                    : (rawData is Map && rawData['items'] is List
                        ? rawData['items'] as List
                        : const []);

                if (items.isEmpty) {
                  return const Center(child: Text("Belum ada riwayat transaksi"));
                }

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.teal),
                          SizedBox(width: 8),
                          Text("Mutasi Saldo Dompet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final tx = items[i];
                          final isDeposit = tx['type'] == 'DEPOSIT';
                          final double amt = (tx['amount'] is num) ? (tx['amount'] as num).toDouble() : 0.0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isDeposit ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                            title: Text(tx['description'] ?? 'Transaksi Dompet', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              tx['createdAt'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()) : '-',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            trailing: Text(
                              "${isDeposit ? '+' : '-'}${_currencyFormat.format(amt)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDeposit ? Colors.green : Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 110),
            _buildWithdrawalForm(),
            const SizedBox(height: 24),
            const AppFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      bottomNavigationBar: _buildBottomBar(),
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
            image: DecorationImage(
              image: AssetImage('assets/bg2.png'),
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
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    'Pencairan Dana',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: _showTransactionHistoryDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/icons/riwayat.png', width: 18, height: 18),
                      const SizedBox(width: 6),
                      const Text('Mutasi', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
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

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo yang Bisa Ditarik', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          _isLoadingWallet
              ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  children: [
                    Image.asset('assets/icons/dompet.png', width: 34, height: 34),
                    const SizedBox(width: 12),
                    Text(
                      _currencyFormat.format(_balance),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.teal),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Biaya admin transfer antar-rekening flat Rp 2.500 per transaksi.",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalForm() {
    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double enteredAmount = double.tryParse(rawAmount) ?? 0.0;
    final double totalEstimatedDeduction = enteredAmount > 0 ? enteredAmount + adminFee : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Metode Pencairan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeSelector('BANK', 'Transfer Bank', Icons.account_balance),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeSelector('EWALLET', 'E-Wallet', Icons.phone_android),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Pilih Penyedia:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_selectedMethodType == 'BANK' ? _bankOptions : _ewalletOptions).map((prov) {
              final isSelected = _selectedProvider == prov;
              return ChoiceChip(
                label: Text(prov, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                selected: isSelected,
                selectedColor: primary,
                backgroundColor: const Color(0xFFF4F6F8),
                onSelected: (val) {
                  if (val) setState(() => _selectedProvider = prov);
                },
              );
            }).toList(),
          ),
          const Divider(height: 28),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _selectedMethodType == 'BANK' ? 'Nomor Rekening' : 'Nomor Handphone E-Wallet',
              hintText: _selectedMethodType == 'BANK' ? 'Contoh: 1234567890' : 'Contoh: 081234567890',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountHolderController,
            decoration: InputDecoration(
              labelText: 'Nama Pemilik Rekening / Akun',
              hintText: 'Sesuai buku tabungan / KTP',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              labelText: 'Nominal Penarikan',
              hintText: 'Minimal 10.000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Minimal Rp 10.000', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              InkWell(
                onTap: () {
                  final double maxWithdrawable = _balance - adminFee;
                  if (maxWithdrawable >= 10000) {
                    setState(() {
                      _amountController.text = maxWithdrawable.toInt().toString();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Saldo tidak cukup setelah dipotong admin Rp 2.500"), backgroundColor: Colors.orange),
                    );
                  }
                },
                child: Text('Tarik Maksimal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
              ),
            ],
          ),
          if (enteredAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Saldo Terpotong (+Admin):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _currencyFormat.format(totalEstimatedDeduction),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: totalEstimatedDeduction <= _balance ? Colors.black87 : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String type, String label, IconData icon) {
    final bool active = _selectedMethodType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethodType = type;
          _selectedProvider = type == 'BANK' ? _bankOptions.first : _ewalletOptions.first;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.12) : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? primary : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? primary : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? primary : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final String rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double amount = double.tryParse(rawAmount) ?? 0;
    final double totalRequired = amount + adminFee;
    final bool valid = amount >= 10000 && totalRequired <= _balance && !_isSubmitting && !_isLoadingWallet;

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: valid ? _submitWithdrawal : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: valid ? primary : Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    valid ? "Tarik ${_currencyFormat.format(amount)}" : "Masukkan Nominal Valid",
                    style: TextStyle(
                      color: valid ? Colors.white : Colors.grey.shade600,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}