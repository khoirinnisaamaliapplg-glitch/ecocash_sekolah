import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:http/http.dart' as http;

/// Error returned by [ApiClient].
///
/// Carries the backend envelope (`message`, `code`, `errors`) so screens can
/// show the server's message instead of a generic "terjadi kesalahan".
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.errors,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isEmailNotVerified =>
      code == 'EMAIL_NOT_VERIFIED' || message.contains('EMAIL_NOT_VERIFIED');

  @override
  String toString() => message;
}

/// Small wrapper around `package:http` shared by every screen.
///
/// Responsibilities:
///  - one timeout for every request (previously only 2 of ~25 calls had one);
///  - unwrap the `{ success, message, data }` envelope;
///  - turn every failure into [ApiException] with a readable message;
///  - on 401 clear the token and call [onUnauthorized] so the app can send the
///    user back to the login page (instead of every screen doing its own thing).
class ApiClient {
  ApiClient._();

  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Wired once in `main.dart` (navigates to the login page).
  static void Function()? onUnauthorized;

  static bool _handlingUnauthorized = false;

  static Future<dynamic> get(
    String url, {
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) =>
      _send(
        'GET',
        url,
        auth: auth,
        timeout: timeout,
        headers: headers,
      );

  static Future<dynamic> post(
    String url, {
    Object? body,
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) =>
      _send(
        'POST',
        url,
        body: body,
        auth: auth,
        timeout: timeout,
        headers: headers,
      );

  static Future<dynamic> patch(
    String url, {
    Object? body,
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) =>
      _send(
        'PATCH',
        url,
        body: body,
        auth: auth,
        timeout: timeout,
        headers: headers,
      );

  static Future<dynamic> delete(
    String url, {
    Object? body,
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) =>
      _send(
        'DELETE',
        url,
        body: body,
        auth: auth,
        timeout: timeout,
        headers: headers,
      );

  /// GET that always returns a JSON object (throws [ApiException] otherwise).
  static Future<Map<String, dynamic>> getMap(
    String url, {
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    final data = await get(url, auth: auth, timeout: timeout, headers: headers);
    return _asMap(data);
  }

  /// GET that keeps the whole response envelope (`data` **and** `meta`).
  ///
  /// Needed when the total matters, e.g. counting unconfirmed sessions with
  /// `GET /machine-sessions/my?status=WAITING_CONFIRMATION&limit=1` — the
  /// count lives in `meta.total`, outside `data`.
  static Future<Map<String, dynamic>> getEnvelope(
    String url, {
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    final dynamic body = await _send(
      'GET',
      url,
      auth: auth,
      timeout: timeout,
      headers: headers,
      unwrap: false,
    );

    if (body is Map) return Map<String, dynamic>.from(body);

    return <String, dynamic>{};
  }

  /// GET that always returns a JSON list (throws [ApiException] otherwise).
  static Future<List<dynamic>> getList(
    String url, {
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    final data = await get(url, auth: auth, timeout: timeout, headers: headers);
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    return const <dynamic>[];
  }

  /// Unggah satu file ke `POST /upload/single` (multipart).
  ///
  /// `fields` dikirim lebih dulu daripada file: multer di server memakai
  /// `category` untuk menentukan folder tujuan dan memproses part sesuai
  /// urutannya. Mengembalikan `{ filename, originalname, mimetype, size, path,
  /// url }` (sudah di-unwrap dari envelope `data`).
  static Future<Map<String, dynamic>> uploadFile(
    String url, {
    required String filePath,
    String field = 'file',
    Map<String, String> fields = const <String, String>{},
    Duration? timeout,
  }) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse(url),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      // Jangan set Content-Type: boundary multipart dibuat oleh http.
      if (ApiConfig.hasToken)
        'Authorization': 'Bearer ${ApiConfig.userToken!.trim()}',
    });

    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(field, filePath));

    final Duration limit = timeout ?? const Duration(seconds: 60);

    try {
      final http.StreamedResponse streamed = await request
          .send()
          .timeout(limit);
      final http.Response response = await http.Response.fromStream(
        streamed,
      ).timeout(limit);

      final dynamic decoded = _decode(response);

      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on TimeoutException {
      throw const ApiException('Unggah file terlalu lama. Coba lagi.');
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server EcoCash. Periksa jaringan Anda.',
      );
    } on http.ClientException {
      throw const ApiException('Koneksi ke server terputus. Coba lagi.');
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException('Format respons server tidak valid.');
  }

  static Map<String, String> _buildHeaders({
    required bool auth,
    Map<String, String>? extra,
  }) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && ApiConfig.hasToken)
        'Authorization': 'Bearer ${ApiConfig.userToken!.trim()}',
      ...?extra,
    };
  }

  static Future<dynamic> _send(
    String method,
    String url, {
    Object? body,
    bool auth = true,
    Duration? timeout,
    Map<String, String>? headers,
    bool unwrap = true,
  }) async {
    final request = http.Request(method, Uri.parse(url))
      ..headers.addAll(_buildHeaders(auth: auth, extra: headers));

    if (body != null) {
      request.body = body is String ? body : jsonEncode(body);
    }

    final limit = timeout ?? defaultTimeout;

    try {
      final streamed = await request.send().timeout(limit);
      final response = await http.Response.fromStream(streamed).timeout(limit);
      return _decode(response, unwrap: unwrap);
    } on TimeoutException {
      throw const ApiException(
        'Server tidak merespons. Periksa koneksi lalu coba lagi.',
      );
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server EcoCash. Periksa jaringan Anda.',
      );
    } on http.ClientException {
      throw const ApiException('Koneksi ke server terputus. Coba lagi.');
    }
  }

  static dynamic _decode(http.Response response, {bool unwrap = true}) {
    final status = response.statusCode;
    final rawBody = response.body.trim();

    dynamic decoded;
    if (rawBody.isNotEmpty) {
      try {
        decoded = jsonDecode(rawBody);
      } catch (_) {
        decoded = null;
      }
    }

    if (status >= 200 && status < 300) {
      if (unwrap && decoded is Map && decoded.containsKey('data')) {
        return decoded['data'];
      }

      return decoded ?? rawBody;
    }

    final code = decoded is Map ? decoded['code']?.toString() : null;
    final errors = decoded is Map ? decoded['errors'] : null;
    final message = _extractMessage(decoded) ?? 'Permintaan gagal ($status).';

    if (status == 401) {
      ApiConfig.clearToken();
      _notifyUnauthorized();
    }

    throw ApiException(
      message,
      statusCode: status,
      code: code,
      errors: errors,
    );
  }

  static String? _extractMessage(dynamic decoded) {
    if (decoded is! Map) return null;

    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) return message;

    final error = decoded['error'];
    if (error is String && error.trim().isNotEmpty) return error;

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        final path = first['path'];
        final msg = first['msg'];
        if (path != null && msg != null) return '$path: $msg';
        if (msg != null) return msg.toString();
      }
      return first.toString();
    }

    return null;
  }

  /// Debounced so a screen firing three parallel requests does not push the
  /// login page three times.
  static void _notifyUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    onUnauthorized?.call();
    Timer(const Duration(seconds: 2), () => _handlingUnauthorized = false);
  }
}
