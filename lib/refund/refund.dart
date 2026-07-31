import 'dart:convert';

import 'package:ecocash_sekolah/app_footer.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    _sessionsFuture = _fetchSessions();
  }

  // ============================================================
  // FETCH SESSION HISTORY
  // ============================================================

  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getMySessionHistory),
      headers: ApiConfig.headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal memuat riwayat: '
        '${response.statusCode}',
      );
    }

    final dynamic decodedResponse = jsonDecode(response.body);

    if (decodedResponse is! Map<String, dynamic>) {
      throw Exception('Format respons riwayat tidak sesuai');
    }

    final dynamic rawData = decodedResponse['data'];

    if (rawData is! List) {
      return [];
    }

    final List<Map<String, dynamic>> sessions = rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    /*
     * Setiap sesi dilengkapi dengan:
     * 1. Detail sesi untuk menghitung berat dan pendapatan.
     * 2. Detail mesin untuk memperoleh lokasi.
     */
    final List<Map<String, dynamic>> completedSessions = await Future.wait(
      sessions.map(_completeSessionData),
    );

    return completedSessions;
  }

  Future<Map<String, dynamic>> _completeSessionData(
    Map<String, dynamic> session,
  ) async {
    final Map<String, dynamic> result = Map<String, dynamic>.from(session);

    final Map<String, dynamic> machine = _extractMap(session['machine']);

    result['machine'] = machine;

    final String sessionId = session['id']?.toString() ?? '';

    final int? machineId = int.tryParse(machine['id']?.toString() ?? '');

    // Ambil detail sesi dan detail mesin secara bersamaan.
    final List<Future<void>> requests = [];

    if (sessionId.isNotEmpty) {
      requests.add(_addSessionDetail(result, sessionId));
    }

    if (machineId != null) {
      requests.add(_addMachineDetail(result, machineId));
    }

    await Future.wait(requests);

    // Pastikan selalu terdapat nilai numerik.
    result['currentWeight'] = _toDouble(result['currentWeight']);

    result['totalPrice'] = _toDouble(result['totalPrice']);

    return result;
  }

  // ============================================================
  // FETCH SESSION DETAIL
  // ============================================================

  Future<void> _addSessionDetail(
    Map<String, dynamic> target,
    String sessionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSessionDetail(sessionId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Detail sesi $sessionId gagal: '
          '${response.statusCode}',
        );

        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final Map<String, dynamic> detail = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;

      final List<dynamic> items = detail['items'] is List
          ? List<dynamic>.from(detail['items'])
          : [];

      double itemsWeight = 0;
      double itemsPrice = 0;

      for (final dynamic rawItem in items) {
        if (rawItem is! Map) {
          continue;
        }

        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

        itemsWeight += _toDouble(item['weight']);

        itemsPrice += _toDouble(item['totalPrice']);
      }

      final Map<String, dynamic> summary = _extractMap(detail['summary']);

      final double summaryWeight = _toDouble(summary['currentWeight']);

      final double summaryPrice = _toDouble(summary['totalPrice']);

      final double historyWeight = _toDouble(target['currentWeight']);

      final double historyPrice = _toDouble(target['totalPrice']);

      /*
       * Prioritas nilai:
       * 1. Hasil penjumlahan items.
       * 2. Summary detail sesi.
       * 3. Nilai dari daftar history.
       */
      target['currentWeight'] = itemsWeight > 0
          ? itemsWeight
          : summaryWeight > 0
          ? summaryWeight
          : historyWeight;

      target['totalPrice'] = itemsPrice > 0
          ? itemsPrice
          : summaryPrice > 0
          ? summaryPrice
          : historyPrice;

      if (detail['status'] != null) {
        target['status'] = detail['status'];
      }

      if (detail['startedAt'] != null) {
        target['startedAt'] = detail['startedAt'];
      }

      if (detail['endedAt'] != null) {
        target['endedAt'] = detail['endedAt'];
      }

      target['items'] = items;
    } catch (error) {
      debugPrint(
        'Gagal mengambil detail sesi '
        '$sessionId: $error',
      );
    }
  }

  // ============================================================
  // FETCH MACHINE DETAIL
  // ============================================================

  Future<void> _addMachineDetail(
    Map<String, dynamic> target,
    int machineId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getMachineById(machineId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Detail mesin $machineId gagal: '
          '${response.statusCode}',
        );

        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final Map<String, dynamic> machineDetail = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;

      final Map<String, dynamic> oldMachine = _extractMap(target['machine']);

      target['machine'] = {...oldMachine, ...machineDetail};
    } catch (error) {
      debugPrint(
        'Gagal mengambil detail mesin '
        '$machineId: $error',
      );
    }
  }

  Map<String, dynamic> _extractMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshSessions() async {
    final Future<List<Map<String, dynamic>>> newFuture = _fetchSessions();

    setState(() {
      _sessionsFuture = newFuture;
    });

    await newFuture;
  }

  // ============================================================
  // FORMAT DATA
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    try {
      final DateTime date = DateTime.parse(value.toString()).toLocal();

      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatSessionDate(Map<String, dynamic> session) {
    final dynamic dateValue = session['startedAt'] ?? session['createdAt'];

    return _formatDate(dateValue);
  }

  String _getMachineName(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String name = machine['name']?.toString().trim() ?? '';

    return name.isNotEmpty ? name : 'Mesin tidak diketahui';
  }

  String _getMachineCode(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String machineCode = machine['machineCode']?.toString().trim() ?? '';

    return machineCode.isNotEmpty ? machineCode : '-';
  }

  String _getMachineLocation(Map<String, dynamic> session) {
    final Map<String, dynamic> machine = _extractMap(session['machine']);

    final String placeName = machine['placeName']?.toString().trim() ?? '';

    final String address = machine['address']?.toString().trim() ?? '';

    final String subdistrict = machine['subdistrict']?.toString().trim() ?? '';

    final String district = machine['district']?.toString().trim() ?? '';

    if (placeName.isNotEmpty && address.isNotEmpty) {
      return '$placeName, $address';
    }

    if (address.isNotEmpty) {
      return address;
    }

    if (placeName.isNotEmpty) {
      return placeName;
    }

    final List<String> locationParts = [
      subdistrict,
      district,
    ].where((value) => value.isNotEmpty).toList();

    if (locationParts.isNotEmpty) {
      return locationParts.join(', ');
    }

    return 'Lokasi tidak tersedia';
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Sedang Berlangsung';

      case 'WAITING_CONFIRMATION':
        return 'Menunggu Konfirmasi';

      case 'COMPLETED':
        return 'Selesai';

      case 'CANCELLED':
        return 'Dibatalkan';

      case 'EXPIRED':
        return 'Kedaluwarsa';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF1976D2);

      case 'WAITING_CONFIRMATION':
        return const Color(0xFFF57C00);

      case 'COMPLETED':
        return const Color(0xFF2E7D32);

      case 'CANCELLED':
      case 'EXPIRED':
        return const Color(0xFFC62828);

      default:
        return const Color(0xFF757575);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          final List<Map<String, dynamic>> sessions = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refreshSessions,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context, sessions),

                  const SizedBox(height: 140),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    )
                  else if (snapshot.hasError)
                    _buildErrorState(snapshot.error.toString())
                  else if (sessions.isEmpty)
                    _buildEmptyState()
                  else
                    _buildSessionList(sessions),

                  const SizedBox(height: 24),
                  const AppFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 50),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshSessions,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            'Belum ada riwayat sesi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SESSION LIST
  // ============================================================

  Widget _buildSessionList(List<Map<String, dynamic>> sessions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildListHeader(),

              ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (context, index) {
                  return const Divider(height: 1);
                },
                itemBuilder: (context, index) {
                  return _buildSessionItem(sessions[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final String status = session['status']?.toString() ?? 'UNKNOWN';

    final Color statusColor = _statusColor(status);

    final double currentWeight = _toDouble(session['currentWeight']);

    final double totalPrice = _toDouble(session['totalPrice']);

    final String machineName = _getMachineName(session);

    final String machineCode = _getMachineCode(session);

    final String machineLocation = _getMachineLocation(session);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.recycling_rounded, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          machineName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            _formatSessionDate(session),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _detailRow(label: 'Kode Mesin', value: machineCode),

                const Divider(height: 22),

                _detailRow(label: 'Lokasi', value: machineLocation),

                const Divider(height: 22),

                _detailRow(
                  label: 'Berat Sampah',
                  value: '${currentWeight.toStringAsFixed(2)} kg',
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Pendapatan',
                  value: _currencyFormat.format(totalPrice),
                  valueColor: const Color(0xFF107569),
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Mulai',
                  value: _formatDate(
                    session['startedAt'] ?? session['createdAt'],
                  ),
                ),

                const Divider(height: 22),

                _detailRow(
                  label: 'Selesai',
                  value: _formatDate(session['endedAt']),
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF263238),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(color: Color(0xFFFFD966)),
      child: const Row(
        children: [
          Icon(Icons.history_rounded, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'Riwayat Sesi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    BuildContext context,
    List<Map<String, dynamic>> sessions,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg4.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 25, left: 20),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -110,
          left: 15,
          right: 15,
          child: _buildSummaryCard(sessions),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> sessions) {
    final int totalSessions = sessions.length;

    final double totalWeight = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['currentWeight']);
    });

    final double totalEarnings = sessions.fold<double>(0, (total, session) {
      return total + _toDouble(session['totalPrice']);
    });

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset('assets/icons/mingcute.png', width: 45, height: 45),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Session History',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                ),
                Image.asset('assets/icons/share.png', width: 42, height: 42),
              ],
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                _buildInfoBox(
                  'Total Sesi',
                  totalSessions.toString(),
                  const Color(0xFFE6F9E6),
                ),

                const SizedBox(width: 10),

                _buildInfoBox(
                  'Total Berat',
                  '${totalWeight.toStringAsFixed(2)} kg',
                  const Color(0xFFE6F2FA),
                ),

                const SizedBox(width: 10),

                _buildInfoBox(
                  'Pendapatan',
                  _currencyFormat.format(totalEarnings),
                  const Color(0xFFFFF9E6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 6),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
