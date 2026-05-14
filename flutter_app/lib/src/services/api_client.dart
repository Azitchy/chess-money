import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl})
    : _baseUrl = baseUrl ?? 'http://10.0.2.2:8000/api';

  final String _baseUrl;
  String? _token;

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
  }) async {
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

    return _handleAuthResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: _headers,
      body: jsonEncode({'login': login, 'password': password}),
    );

    return _handleAuthResponse(response);
  }

  Future<void> logout() async {
    await http.post(Uri.parse('$_baseUrl/logout'), headers: _headers);
    _token = null;
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

  Map<String, dynamic> _handleAuthResponse(http.Response response) {
    final data = _decode(response);
    _token = data['token'] as String;
    return data;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        payload['message'] ?? 'Request failed (${response.statusCode})',
      );
    }
    return payload;
  }
}
