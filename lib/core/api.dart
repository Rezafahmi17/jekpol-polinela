import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final Map<String, dynamic> data;
  ApiException(this.message, {this.status, this.data = const {}});

  String? get code => data['code'] as String?;

  @override
  String toString() => message;
}

/// Klien REST API (Flutter → PHP → MySQL).
class Api {
  Api._();

  static String? token;
  static void Function()? onUnauthorized;

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = '${AppConfig.baseUrl}/$path';
    final q = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse(base).replace(queryParameters: q?.isEmpty ?? true ? null : q);
  }

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'X-Auth-Token': token!,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// URL gambar/dokumen yang membutuhkan autentikasi (dipakai Image.network).
  static String authedUrl(String path) => '${AppConfig.baseUrl}/$path';
  static Map<String, String> get authHeaders => {if (token != null) 'X-Auth-Token': token!};

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers));

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) => _send(() => http.post(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      ));

  static Future<Map<String, dynamic>> multipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String> files = const {},
  }) =>
      _send(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers)
          ..fields.addAll(fields);
        for (final e in files.entries) {
          req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
        }
        final streamed = await req.send();
        return http.Response.fromStream(streamed);
      }, timeout: const Duration(seconds: 60));

  static Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException('Server tidak merespons. Periksa koneksi dan alamat server.');
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Pastikan Apache & MySQL XAMPP berjalan dan alamat server benar.');
    } on http.ClientException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Pastikan Apache & MySQL XAMPP berjalan dan alamat server benar.');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respons server tidak valid (HTTP ${res.statusCode}). Periksa alamat API.', status: res.statusCode);
    }
    if (json['success'] == true) {
      final d = json['data'];
      final map = d is Map<String, dynamic> ? Map<String, dynamic>.from(d) : <String, dynamic>{};
      map['_message'] = json['message'];
      return map;
    }
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(json['message']?.toString() ?? 'Terjadi kesalahan', status: res.statusCode, data: json);
  }
}

