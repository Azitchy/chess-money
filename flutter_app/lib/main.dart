import 'package:flutter/material.dart';

import 'src/screens/dashboard_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  runApp(ChessMoneyApp(apiClient: apiClient));
}

class ChessMoneyApp extends StatefulWidget {
  const ChessMoneyApp({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ChessMoneyApp> createState() => _ChessMoneyAppState();
}

class _ChessMoneyAppState extends State<ChessMoneyApp> {
  late bool _isAuthenticated;
  bool _demoMode = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.apiClient.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Money',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: _isAuthenticated
          ? DashboardScreen(
              apiClient: widget.apiClient,
              onLogout: _handleLogout,
              demoMode: _demoMode,
            )
          : LoginScreen(
              apiClient: widget.apiClient,
              onLogin: _handleLogin,
              onBypassLogin: _handleBypassLogin,
            ),
    );
  }

  void _handleLogin() {
    setState(() {
      _demoMode = false;
      _isAuthenticated = true;
    });
  }

  void _handleBypassLogin() {
    setState(() {
      _demoMode = true;
      _isAuthenticated = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _demoMode = false;
      _isAuthenticated = false;
    });
  }
}
