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
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.apiClient.isLoggedIn;
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
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
      home: _showSplash
          ? const _StartupSplashScreen()
          : _isAuthenticated
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

class _StartupSplashScreen extends StatelessWidget {
  const _StartupSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FBFF)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'lib/src/assets/splase.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x201D3B73), Color(0xCC0E1F39)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFBFD7FF)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chess Money',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.heading,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Loading your wallet and matches...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
