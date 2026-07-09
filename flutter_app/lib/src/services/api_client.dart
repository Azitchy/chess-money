import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._(this._baseUrl, this._prefs);

  static const _tokenKey = 'auth_token';

  final String _baseUrl;
  final SharedPreferences _prefs;
  String? _token;

  static Future<ApiClient> create({String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient._(baseUrl ?? _defaultBaseUrl(), prefs);
    client._token = prefs.getString(_tokenKey);
    return client;
  }

  static String _defaultBaseUrl() {
    const overrideBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (overrideBaseUrl.isNotEmpty) {
      return overrideBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    return 'http://10.0.2.2:8000/api';
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
    bool persistSession = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      return await _handleAuthResponse(
        response,
        persistSession: persistSession,
      );
    } catch (error) {
      throw Exception(_friendlyNetworkMessage(error));
    }
  }

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    bool persistSession = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: _headers,
        body: jsonEncode({'login': login, 'password': password}),
      );

      return await _handleAuthResponse(
        response,
        persistSession: persistSession,
      );
    } catch (error) {
      throw Exception(_friendlyNetworkMessage(error));
    }
  }

  Future<void> logout() async {
    await http.post(Uri.parse('$_baseUrl/logout'), headers: _headers);
    _token = null;
    await _prefs.remove(_tokenKey);
  }

  Future<double> getWalletBalance() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet'),
      headers: _headers,
    );
    final data = _decode(response);
    return (data['balance'] as num).toDouble();
  }

  Future<List<dynamic>> getMatchHistory() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/matches/history'),
      headers: _headers,
    );
    final data = _decode(response);
    return data['data'] as List<dynamic>;
  }

  Future<void> requestFunds(double amount, {String? note}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/wallet/request-funds'),
      headers: _headers,
      body: jsonEncode({'amount': amount, 'note': note}),
    );

    _decode(response);
  }

  Future<Map<String, dynamic>> createMatch({
    required String mode,
    required double betAmount,
    required String timeControl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/matches'),
      headers: _headers,
      body: jsonEncode({
        'mode': mode,
        'bet_amount': betAmount,
        'time_control': timeControl,
      }),
    );

    return _decode(response);
  }

  Future<void> joinMatch(int matchId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/$matchId/join'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<void> endMatch(int matchId, String result) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/$matchId/end'),
      headers: _headers,
      body: jsonEncode({'result': result}),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> _handleAuthResponse(
    http.Response response, {
    required bool persistSession,
  }) async {
    final data = _decode(response);
    _token = data['token'] as String;
    if (persistSession) {
      await _prefs.setString(_tokenKey, _token!);
    } else {
      await _prefs.remove(_tokenKey);
    }
    return data;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = <String, dynamic>{
        'message': response.body.isEmpty
            ? 'Request failed (${response.statusCode})'
            : response.body,
      };
    }

    if (response.statusCode >= 400) {
      throw Exception(
        payload['message'] ?? 'Request failed (${response.statusCode})',
      );
    }
    return payload;
  }

  String _friendlyNetworkMessage(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Connection timed out')) {
      return 'Cannot reach the API at $_baseUrl. Make sure the backend server is running and the device can access that address.';
    }

    return message;
  }
}
