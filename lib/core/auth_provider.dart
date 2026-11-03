import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? startupError;

  static const _kToken = 'token';
  static const _kBase = 'base_url';

  AuthProvider() {
    Api.onUnauthorized = () => _forceLogout();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    AppConfig.baseUrl = prefs.getString(_kBase) ?? AppConfig.defaultBaseUrl;
    final token = prefs.getString(_kToken);
    startupError = null;
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    Api.token = token;
    try {
      final r = await Api.get('auth/me');
      user = AppUser.fromJson(r['user']);
      status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _clear();
      } else {
        startupError = e.message;
        status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    AppConfig.baseUrl = u.isEmpty ? AppConfig.defaultBaseUrl : u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBase, AppConfig.baseUrl);
    notifyListeners();
  }

  Future<void> _persist(String token) async {
    Api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<void> _clear() async {
    Api.token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  Future<void> login(String identifier, String password) async {
    final r = await Api.post('auth/login', body: {'identifier': identifier, 'password': password});
    await _persist(r['token']);
    user = AppUser.fromJson(r['user']);
    status = AuthStatus.authenticated;
    startupError = null;
    notifyListeners();
  }

  Future<String> register(Map<String, String> fields, {Map<String, String> files = const {}}) async {
    final r = await Api.multipart('auth/register', fields: fields, files: files);
    await _persist(r['token']);
    user = AppUser.fromJson(r['user']);
    status = AuthStatus.authenticated;
    notifyListeners();
    return r['_message'] ?? 'Registrasi berhasil';
  }

  Future<void> refreshUser() async {
    try {
      final r = await Api.get('auth/me');
      user = AppUser.fromJson(r['user']);
      notifyListeners();
    } catch (_) {}
  }

  void setUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Api.post('auth/logout');
    } catch (_) {}
    await _clear();
    notifyListeners();
  }

  Future<void> _forceLogout() async {
    if (status != AuthStatus.authenticated) return;
    await _clear();
    notifyListeners();
  }
}

