import 'package:flutter/material.dart';

import 'src/screens/dashboard_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/services/api_client.dart';

void main() {
  runApp(const ChessMoneyApp());
}

class ChessMoneyApp extends StatefulWidget {
  const ChessMoneyApp({super.key});

  @override
  State<ChessMoneyApp> createState() => _ChessMoneyAppState();
}

class _ChessMoneyAppState extends State<ChessMoneyApp> {
  final ApiClient _apiClient = ApiClient();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Money',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: _apiClient.isLoggedIn
          ? DashboardScreen(apiClient: _apiClient, onLogout: _handleLogout)
          : LoginScreen(apiClient: _apiClient, onLogin: _handleLogin),
    );
  }

  void _handleLogin() {
    setState(() {});
  }

  void _handleLogout() {
    setState(() {});
  }
}
