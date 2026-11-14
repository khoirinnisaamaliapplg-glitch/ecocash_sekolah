import 'dart:convert';
import 'dart:io';

import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hasil [SessionHistoryExporter.exportToCsv].
///
/// [shared] bernilai `false` juga saat pengguna menutup sheet tanpa memilih
/// aplikasi tujuan — file-nya sendiri sudah berhasil dibuat.
class SessionExportResult {
  const SessionExportResult({
    required this.sessionCount,
    required this.fileName,
    required this.filePath,
    required this.shared,
  });

  /// Jumlah sesi yang masuk ke CSV.
  final int sessionCount;

  final String fileName;

  /// `null` bila tidak ada sesi sehingga tidak ada file yang dibuat.
  final String? filePath;

  final bool shared;

  bool get isEmpty => sessionCount == 0;
}

/// Mengunduh riwayat setor sebagai CSV lalu membagikannya lewat share sheet.
///
/// Kenapa CSV dan bukan Excel: pengguna bisa membukanya di Excel/Sheets,
/// mengirimnya ke guru, atau melampirkannya ke email — tanpa dependensi
/// pembuat spreadsheet di sisi aplikasi.
///
/// Yang diambil adalah **seluruh** riwayat, bukan halaman yang sedang
/// tampil: halaman di API dibatasi [pageSize] baris, jadi ekspor berjalan
/// halaman demi halaman sampai `meta.totalPages` habis.
class SessionHistoryExporter {
  SessionHistoryExporter._();

  /// Batas maksimum `limit` yang diterima server pada endpoint ini.
  static const int pageSize = 100;

  /// Pengaman bila `meta.totalPages` bernilai aneh: 200 x 100 = 20.000 sesi.
  static const int _maxPages = 200;

  static const String _delimiter = ',';
  static const String _lineEnd = '\r\n';

  /// Header CSV. Kolom pertama adalah **ID Sesi** supaya tiap baris bisa
  /// dicocokkan dengan sesi aslinya saat menghubungi dukungan.
  static const List<String> header = <String>[
    'ID Sesi',
    'Status',
    'Mesin',
    'Kode Mesin',
    'Lokasi',
    'Mulai',
    'Selesai',
    'Berat (kg)',
    'Total (Rp)',
  ];

  /// Ambil semua halaman, tulis ke file sementara, lalu bagikan.
  ///
  /// [onProgress] dipanggil setiap halaman selesai dengan
  /// `(baris_terkumpul, total_dari_server)` agar UI bisa menampilkan progres.
  static Future<SessionExportResult> exportToCsv({
    void Function(int loaded, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> sessions = await _fetchAll(
      onProgress: onProgress,
    );

    if (sessions.isEmpty) {
      return const SessionExportResult(
        sessionCount: 0,
        fileName: '',
        filePath: null,
        shared: false,
      );
    }

    final String csv = buildCsv(sessions);

    final Directory directory = await getTemporaryDirectory();
    final String stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final String fileName = 'riwayat-setor-$stamp.csv';
    final File file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );

    // BOM UTF-8: tanpa ini Excel di Windows menampilkan teks non-ASCII
    // (mis. "é" pada nama tempat) sebagai karakter rusak.
    await file.writeAsString('\uFEFF$csv', encoding: utf8, flush: true);

    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'text/csv')],
        fileNameOverrides: <String>[fileName],
        subject: 'Riwayat setor sampah EcoCash',
        text:
            'Riwayat setor sampah (${sessions.length} sesi) '
            'dari aplikasi EcoCash Sekolah.',
      ),
    );

    return SessionExportResult(
      sessionCount: sessions.length,
      fileName: fileName,
      filePath: file.path,
      shared: result.status == ShareResultStatus.success,
    );
  }

  /// Semua sesi pengguna, terbaru lebih dulu (mengikuti urutan server).
  static Future<List<Map<String, dynamic>>> _fetchAll({
    void Function(int loaded, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> sessions = <Map<String, dynamic>>[];

    int page = 1;
    int totalPages = 1;
    int total = 0;

    while (page <= totalPages && page <= _maxPages) {
      final Map<String, dynamic> envelope = await ApiClient.getEnvelope(
        '${ApiConfig.getMySessionHistory}'
        '?page=$page&limit=$pageSize&sortBy=createdAt&order=desc',
      );

      final dynamic data = envelope['data'];

      final List<Map<String, dynamic>> rows = data is List
          ? data
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];

      sessions.addAll(rows);

      final dynamic meta = envelope['meta'];

      if (meta is Map) {
        totalPages = meta['totalPages'] is num
            ? (meta['totalPages'] as num).toInt()
            : page;

        total = meta['total'] is num
            ? (meta['total'] as num).toInt()
            : sessions.length;
      } else {
        totalPages = page;

        total = sessions.length;
      }

      onProgress?.call(sessions.length, total);

      // Baris kosong berarti server tidak punya data lagi — berhenti walau
      // `meta` masih mengklaim halaman berikutnya ada.
      if (rows.isEmpty) break;

      page += 1;
    }

    return sessions;
  }

  /// Bangun isi CSV (tanpa BOM). Dipisah supaya bisa diuji tanpa file/IO.
  static String buildCsv(List<Map<String, dynamic>> sessions) {
    final List<List<String>> rows = <List<String>>[header];

    for (final Map<String, dynamic> session in sessions) {
      final Map<String, dynamic> machine = _asMap(session['machine']);

      rows.add(<String>[
        session['id']?.toString() ?? '',
        _statusLabel(session['status']),
        machine['name']?.toString() ?? '',
        machine['machineCode']?.toString() ?? '',
        _location(machine),
        _timestamp(session['startedAt']),
        _timestamp(session['endedAt']),
        _number(session['currentWeight'], decimals: 2),
        _number(session['totalPrice'], decimals: 0),
      ]);
    }

    return rows
        .map((row) => row.map(_escape).join(_delimiter))
        .join(_lineEnd);
  }

  // ============================================================
  // FORMAT
  // ============================================================

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _statusLabel(dynamic status) {
    switch (status?.toString().toUpperCase() ?? '') {
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
        return status?.toString() ?? '';
    }
  }

  static String _location(Map<String, dynamic> machine) {
    final String placeName = machine['placeName']?.toString().trim() ?? '';
    final String address = machine['address']?.toString().trim() ?? '';

    if (placeName.isNotEmpty && address.isNotEmpty) {
      return '$placeName, $address';
    }

    if (address.isNotEmpty) return address;
    if (placeName.isNotEmpty) return placeName;

    final List<String> parts = <String>[
      machine['subdistrict']?.toString().trim() ?? '',
      machine['district']?.toString().trim() ?? '',
    ].where((value) => value.isNotEmpty).toList();

    return parts.join(', ');
  }

  /// Waktu lokal `yyyy-MM-dd HH:mm`; nilai mentah dipakai bila tak bisa di-parse.
  static String _timestamp(dynamic value) {
    if (value == null) return '';

    final String raw = value.toString().trim();
    if (raw.isEmpty) return '';

    try {
      final DateTime date = DateTime.parse(raw).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return raw;
    }
  }

  /// Angka polos dengan titik desimal (bukan format ribuan) supaya Excel
  /// membacanya sebagai angka, bukan teks.
  static String _number(dynamic value, {required int decimals}) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return parsed.toStringAsFixed(decimals);
  }

  /// Escape satu sel: buang baris baru, netralkan formula, kutip bila perlu.
  static String _escape(String value) {
    if (value.isEmpty) return '';

    String cell = value
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');

    // CSV injection: sel yang dimulai `=`, `+`, `-`, `@` bisa dieksekusi
    // sebagai formula saat file dibuka. Prefix apostrof membuatnya teks.
    final String first = cell.substring(0, 1);
    if (first == '=' || first == '+' || first == '-' || first == '@') {
      cell = "'$cell";
    }

    if (cell.contains('"') ||
        cell.contains(_delimiter) ||
        cell.contains('\t') ||
        cell != cell.trim()) {
      cell = '"${cell.replaceAll('"', '""')}"';
    }

    return cell;
  }
}
