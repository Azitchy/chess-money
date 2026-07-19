import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../platform_notification.dart';
import '../registered_user.dart';
import '../live_match.dart';
import '../player_progress.dart';
import '../user_profile.dart';
import '../wallet_conversation.dart';

String friendlyAppErrorMessage(Object error) {
  final rawMessage = error.toString();
  final message = rawMessage.replaceFirst('Exception: ', '').trim();
  const recoveryHint =
      ' Please try logout and login again if it keeps happening. Thank you!';

  if (_isSessionError(error, message)) {
    return 'Session expired. Please logout and login again. Thank you!';
  }

  if (_isTimeoutError(error, message)) {
    return 'Something took too long. Please try again.$recoveryHint';
  }

  if (_isConnectionError(message)) {
    return 'We could not complete your request. Please try again.$recoveryHint';
  }

  if (message.isEmpty) {
    return 'Something went wrong. Please try again.$recoveryHint';
  }

  return 'Something went wrong. Please try again.$recoveryHint';
}

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

    return 'https://hib.dailoride.com/api';
  }

  static String? _normalizeSavedBaseUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return null;
    }

    final normalized = baseUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null || _isLocalDevelopmentHost(uri)) {
      return null;
    }

    return normalized;
  }

  bool get isLoggedIn => _token != null;
  String get baseUrl => _baseUrl;
  String get notificationSocketUrl {
    const overrideSocketUrl = String.fromEnvironment('NOTIFICATION_WS_URL');
    if (overrideSocketUrl.isNotEmpty) {
      return overrideSocketUrl;
    }

    final apiUri = Uri.parse(_baseUrl);
    final host = apiUri.host.isEmpty ? '127.0.0.1' : apiUri.host;
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://$host:8081';
  }

  Future<void> setBaseUrl(String baseUrl) async {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw Exception('Something went wrong. Please try again.');
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
    required String email,
    String? username,
    String? phoneNumber,
    required String password,
    bool persistSession = true,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
      };
      if (username != null && username.trim().isNotEmpty) {
        body['username'] = username.trim();
      }
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        body['phone_number'] = phoneNumber.trim();
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: _headers,
            body: jsonEncode(body),
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
    required String identifier,
    required String password,
    bool persistSession = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: _headers,
            body: jsonEncode({'identifier': identifier, 'password': password}),
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

  Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    bool persistSession = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/google-login'),
            headers: _headers,
            body: jsonEncode({'id_token': idToken}),
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
    final token = _token;
    _token = null;
    await _prefs.remove(_tokenKey);

    if (token == null) {
      return;
    }

    try {
      await http
          .post(
            Uri.parse('$_baseUrl/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // Logout should always complete locally even if the backend is slow.
    }
  }

  Future<double> getWalletBalance() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/wallet'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return double.tryParse(data['balance']?.toString() ?? '') ?? 0;
  }

  Future<PlayerProgress> getPlayerProgress() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/me'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return PlayerProgress.fromJson(data);
  }

  Future<PlayerProgress> completePuzzle({
    required String puzzleId,
    required String theme,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/progress/puzzle-completed'),
          headers: _headers,
          body: jsonEncode({'puzzle_id': puzzleId, 'theme': theme}),
        )
        .timeout(_requestTimeout);
    return PlayerProgress.fromJson(_decode(response));
  }

  Future<PlayerProgress> completeBotGame({
    required String gameId,
    required String difficulty,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/progress/bot-won'),
          headers: _headers,
          body: jsonEncode({'game_id': gameId, 'difficulty': difficulty}),
        )
        .timeout(_requestTimeout);
    return PlayerProgress.fromJson(_decode(response));
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
          (json) =>
              RegisteredUser.fromJson(json, resolveAvatarUrl: resolveMediaUrl),
        )
        .toList(growable: false);
  }

  Future<List<PlatformNotificationItem>> getPlatformNotifications() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/notifications'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    final notifications = data['data'] as List<dynamic>;
    return notifications
        .whereType<Map<String, dynamic>>()
        .map(PlatformNotificationItem.fromJson)
        .toList(growable: false);
  }

  Future<List<PlatformNotificationItem>> markPlatformNotificationsSeen() async {
    final response = await http
        .post(Uri.parse('$_baseUrl/notifications/mark-seen'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    final notifications = data['data'] as List<dynamic>;
    return notifications
        .whereType<Map<String, dynamic>>()
        .map(PlatformNotificationItem.fromJson)
        .toList(growable: false);
  }

  Future<bool> getPresence() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/presence'), headers: _headers)
        .timeout(_requestTimeout);
    return _decode(response)['is_online'] == true;
  }

  Future<bool> updatePresence(bool isOnline) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/presence'),
          headers: _headers,
          body: jsonEncode({'is_online': isOnline}),
        )
        .timeout(_requestTimeout);
    return _decode(response)['is_online'] == true;
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
          body: jsonEncode({'amount': amount, 'body': note}),
        )
        .timeout(_requestTimeout);

    _decode(response);
  }

  Future<List<WalletConversation>> getWalletConversations({
    String? type,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/wallet/conversations',
    ).replace(queryParameters: type == null ? null : {'type': type});
    final response = await http
        .get(uri, headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return _conversationList(data['data']);
  }

  Future<WalletConversation> getWalletConversation(int conversationId) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/wallet/conversations/$conversationId'),
          headers: _headers,
        )
        .timeout(_requestTimeout);
    return WalletConversation.fromJson(_decode(response));
  }

  Future<WalletConversation> sendWalletConversationMessage(
    int conversationId, {
    String? body,
    Uint8List? attachmentBytes,
    String? attachmentFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/wallet/conversations/$conversationId/reply'),
    );
    request.headers.addAll(_headers);
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    if (attachmentBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          attachmentBytes,
          filename: attachmentFilename ?? 'attachment.jpg',
        ),
      );
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return WalletConversation.fromJson(_decode(response));
  }

  Future<void> deleteWalletConversation(int conversationId) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/wallet/conversations/$conversationId'),
          headers: _headers,
        )
        .timeout(_requestTimeout);
    _decode(response);
  }

  Future<WalletConversation> createWalletConversation({
    required double amount,
    String? body,
    Uint8List? attachmentBytes,
    String? attachmentFilename,
    String requestType = 'funding',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        requestType == 'withdrawal'
            ? '$_baseUrl/wallet/request-withdrawal'
            : '$_baseUrl/wallet/request-funds',
      ),
    );
    request.headers.addAll(_headers);
    request.fields['amount'] = amount.toString();
    request.fields['request_type'] = requestType;
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    if (attachmentBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          attachmentBytes,
          filename: attachmentFilename ?? 'attachment.jpg',
        ),
      );
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return WalletConversation.fromJson(_decode(response));
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

  Future<LiveMatch> acceptChallenge(int matchId) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/matches/$matchId/accept'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return LiveMatch.fromJson(data['match'] as Map<String, dynamic>);
  }

  Future<List<LiveMatch>> getChallenges() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/matches/challenges'), headers: _headers)
        .timeout(_requestTimeout);
    return _liveMatchList(_decode(response)['data']);
  }

  Future<List<LiveMatch>> getActiveMatches() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/matches/active'), headers: _headers)
        .timeout(_requestTimeout);
    return _liveMatchList(_decode(response)['data']);
  }

  Future<void> rejectChallenge(int matchId) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/matches/$matchId/reject'), headers: _headers)
        .timeout(_requestTimeout);
    _decode(response);
  }

  Future<LiveMatch> getMatchState(int matchId) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/matches/$matchId/state'), headers: _headers)
        .timeout(_requestTimeout);
    final data = _decode(response);
    return LiveMatch.fromJson(data['match'] as Map<String, dynamic>);
  }

  Future<LiveMatch> submitMove(
    int matchId, {
    required String from,
    required String to,
    String promotion = 'q',
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/matches/$matchId/move'),
          headers: _headers,
          body: jsonEncode({'from': from, 'to': to, 'promotion': promotion}),
        )
        .timeout(_requestTimeout);
    final data = _decode(response);
    return LiveMatch.fromJson(data['match'] as Map<String, dynamic>);
  }

  Future<bool> endMatch(int matchId, String result) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/matches/$matchId/end'),
          headers: _headers,
          body: jsonEncode({'result': result}),
        )
        .timeout(_requestTimeout);
    return _decode(response)['confirmed'] == true;
  }

  List<LiveMatch> _liveMatchList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(LiveMatch.fromJson)
        .toList(growable: false);
  }

  List<WalletConversation> _conversationList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(WalletConversation.fromJson)
        .toList(growable: false);
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
        'message': 'Something went wrong. Please try again.',
      };
    }

    if (response.statusCode >= 400) {
      if (response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 419) {
        throw Exception(
          'Session expired. Please logout and login again. Thank you!',
        );
      }
      throw Exception('Something went wrong. Please try again.');
    }
    return payload;
  }

  String _friendlyNetworkMessage(Object error) {
    if (error is TimeoutException) {
      return 'Something took too long. Please try again later.';
    }

    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Connection timed out')) {
      return 'We could not connect right now. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }

  static bool _isLocalDevelopmentHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return true;
    }

    if (host == '10.0.2.2') {
      return true;
    }

    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }

    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
      octets.add(value);
    }

    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}

bool _isSessionError(Object error, String message) {
  final lower = message.toLowerCase();
  return lower.contains('session expired') ||
      lower.contains('unauthenticated') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('token') ||
      lower.contains('login again') ||
      lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('419');
}

bool _isTimeoutError(Object error, String message) {
  return error is TimeoutException ||
      message.contains('TimeoutException') ||
      message.contains('Future not completed');
}

bool _isConnectionError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable');
}
