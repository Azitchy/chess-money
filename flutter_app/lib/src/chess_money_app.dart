import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'services/api_client.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

class ChessMoneyApp extends StatefulWidget {
  const ChessMoneyApp({super.key, required this.apiClient});

  final ApiClient apiClient;

  static Future<ChessMoneyApp> create() async {
    final apiClient = await ApiClient.create();
    return ChessMoneyApp(apiClient: apiClient);
  }

  @override
  State<ChessMoneyApp> createState() => _ChessMoneyAppState();
}

class _ChessMoneyAppState extends State<ChessMoneyApp> {
  late bool _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.apiClient.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Money',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        scaffoldBackgroundColor: AppColors.pageBackground,
        useMaterial3: true,
      ),
      home: _isAuthenticated
          ? DashboardScreen(
              apiClient: widget.apiClient,
              onLogout: _handleLogout,
            )
          : LoginScreen(apiClient: widget.apiClient, onLogin: _handleLogin),
    );
  }

  void _handleLogin() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }
}
