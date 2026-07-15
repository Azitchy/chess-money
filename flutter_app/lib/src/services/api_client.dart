import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../registered_user.dart';
import '../user_profile.dart';

class ApiClient {
  ApiClient._(this._baseUrl, this._prefs);

  static const _tokenKey = 'auth_token';
  static const _baseUrlKey = 'api_base_url';
  static const _requestTimeout = Duration(seconds: 15);

  String _baseUrl;
  final SharedPreferences _prefs;
  String? _token;

  static Future<ApiClient> create({String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = _normalizeSavedBaseUrl(prefs.getString(_baseUrlKey));
    final client = ApiClient._(
      baseUrl ?? savedBaseUrl ?? _defaultBaseUrl(),
      prefs,
    );
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

    // Physical devices cannot reach the development computer through
    // localhost. This is the computer's current Wi-Fi/LAN address.
    return 'http://192.168.0.195:8000/api';
  }

  static String? _normalizeSavedBaseUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return null;
    }

    final normalized = baseUrl.trim();
    final staleLocalHosts = [
      'http://10.0.2.2:8000/api',
      'http://127.0.0.1:8000/api',
      'http://localhost:8000/api',
      // Previous development-machine address. Ignore it so existing installs
      // migrate to the current default instead of keeping an unreachable URL.
      'http://192.168.0.191:8000/api',
    ];

    if (staleLocalHosts.contains(normalized)) {
      return null;
    }

    return normalized;
  }

  bool get isLoggedIn => _token != null;
  String get baseUrl => _baseUrl;

  Future<void> setBaseUrl(String baseUrl) async {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw Exception('Backend URL cannot be empty');
    }

    _baseUrl = normalized.endsWith('/api') ? normalized : '$normalized/api';
    await _prefs.setString(_baseUrlKey, _baseUrl);
  }

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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_requestTimeout);

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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: _headers,
            body: jsonEncode({'login': login, 'password': password}),
          )
          .timeout(_requestTimeout);

      return await _handleAuthResponse(
        response,
        persistSession: persistSession,
      );
    } catch (error) {
      throw Exception(_friendlyNetworkMessage(error));
    }
  }

  Future<void> logout() async {
    await http
        .post(Uri.parse('$_baseUrl/logout'), headers: _headers)
        .timeout(_requestTimeout);
    _token = null;
    await _prefs.remove(_tokenKey);
  }

  Future<double> getWalletBalance() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/wallet'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return (data['balance'] as num).toDouble();
  }

  Future<List<dynamic>> getMatchHistory() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/matches/history'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return data['data'] as List<dynamic>;
  }

  Future<List<RegisteredUser>> getUsers() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/users'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    final users = data['data'] as List<dynamic>;
    return users
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => RegisteredUser.fromJson(
            json,
            resolveAvatarUrl: resolveMediaUrl,
          ),
        )
        .toList(growable: false);
  }

  Future<UserProfile> getProfile() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/profile'), headers: _headers)
        .timeout(_requestTimeout);
    return UserProfile.fromJson(
      _decode(response),
      resolveAvatarUrl: resolveMediaUrl,
    );
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String email,
    required String phoneNumber,
    required String address,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/profile'),
    );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields.addAll({
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'address': address,
    });
    if (avatarBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          avatarBytes,
          filename: avatarFilename ?? 'avatar.jpg',
        ),
      );
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    return UserProfile.fromJson(
      data['user'] as Map<String, dynamic>,
      resolveAvatarUrl: resolveMediaUrl,
    );
  }

  String? resolveMediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final mediaUri = Uri.tryParse(value);
    if (mediaUri != null && mediaUri.hasScheme) {
      return mediaUri.toString();
    }

    final apiUri = Uri.parse(_baseUrl);
    final path = value.startsWith('/') ? value : '/$value';
    return apiUri.replace(path: path, query: null, fragment: null).toString();
  }

  Future<void> requestFunds(double amount, {String? note}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/wallet/request-funds'),
          headers: _headers,
          body: jsonEncode({'amount': amount, 'note': note}),
        )
        .timeout(_requestTimeout);

    _decode(response);
  }

  Future<Map<String, dynamic>> createMatch({
    required String mode,
    required double betAmount,
    required String timeControl,
    int? opponentId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/matches'),
          headers: _headers,
          body: jsonEncode({
            'mode': mode,
            'bet_amount': betAmount,
            'time_control': timeControl,
            'opponent_id': opponentId,
          }),
        )
        .timeout(_requestTimeout);

    return _decode(response);
  }

  Future<void> joinMatch(int matchId) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/matches/$matchId/join'), headers: _headers)
        .timeout(_requestTimeout);
    _decode(response);
  }

  Future<void> endMatch(int matchId, String result) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/matches/$matchId/end'),
          headers: _headers,
          body: jsonEncode({'result': result}),
        )
        .timeout(_requestTimeout);
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
    if (error is TimeoutException) {
      return 'Request timed out while contacting the API at $_baseUrl. Check the backend server and network connection.';
    }

    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Connection timed out')) {
      return 'Cannot reach the API at $_baseUrl. Make sure the backend server is running and the device can access that address.';
    }

    return message;
  }
}
