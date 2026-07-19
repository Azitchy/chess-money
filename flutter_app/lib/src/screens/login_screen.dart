import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_colors.dart';
import '../login_decorations.dart';
import '../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.onLogin,
  });

  final ApiClient apiClient;
  final VoidCallback onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          const LoginBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      const AvatarBadge(),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Continue with Google to sign in to your Chess Money account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFDCE9FF)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 30,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _GoogleLoginButton(
                              enabled: !_loading,
                              onPressed: _signInWithGoogle,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEF0),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFFFCED5),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '';
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
    final isApplePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: isApplePlatform && iosClientId.isNotEmpty
            ? iosClientId
            : null,
        // Google requires an OAuth Web client here, never the Android client.
        serverClientId: webClientId.isNotEmpty ? webClientId : null,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception('Google did not return a usable token.');
      }

      await widget.apiClient.googleLogin(
        idToken: idToken,
        accessToken: accessToken,
        persistSession: true,
      );
      widget.onLogin();
    } catch (e) {
      setState(() => _error = _googleLoginErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _googleLoginErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is PlatformException) {
      final details = '${error.message ?? ''} ${error.details ?? ''}';
      if (details.contains('ApiException: 10')) {
        return 'Google OAuth does not match this app package and SHA-1. '
            'Please update the Android OAuth client and try again.';
      }
      if (error.code == 'network_error') {
        return 'Google could not connect. Please check your internet and try again.';
      }
      if (error.code == 'sign_in_canceled') {
        return 'Google sign-in was cancelled.';
      }
    }

    return friendlyAppErrorMessage(error);
  }
}

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF243B67),
          side: const BorderSide(color: Color(0xFFD7E4FA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        icon: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFF6F9FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
