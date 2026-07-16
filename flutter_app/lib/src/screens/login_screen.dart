import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../login_decorations.dart';
import '../login_text_field.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _registerMode = false;
  bool _rememberMe = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

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
                        _registerMode ? 'Create account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.heading,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _registerMode
                            ? 'Set up your Chess Money profile'
                            : 'Sign in to continue to your wallet and matches',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_registerMode) ...[
                                PillTextField(
                                  controller: _name,
                                  label: 'Full name',
                                  icon: Icons.badge_outlined,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                PillTextField(
                                  controller: _username,
                                  label: 'Username',
                                  icon: Icons.person_outline,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                PillTextField(
                                  controller: _email,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                PillTextField(
                                  controller: _login,
                                  label: 'Username or email',
                                  icon: Icons.person_outline,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                              ],
                              PillTextField(
                                controller: _password,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                validator: _required,
                                suffixIcon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: const Color(0xFF5D8FDE),
                                ),
                                onSuffixTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (!_registerMode)
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.scale(
                                          scale: 0.95,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: _loading
                                                ? null
                                                : (value) {
                                                    setState(() {
                                                      _rememberMe =
                                                          value ?? true;
                                                    });
                                                  },
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            activeColor: AppColors.blue,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        const Text(
                                          'Remember me',
                                          style: TextStyle(
                                            color: AppColors.mutedText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _forgotPassword,
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.blue,
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_error != null) ...[
                                const SizedBox(height: 4),
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
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.blue,
                                        AppColors.lavender,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x332A75FF),
                                        blurRadius: 18,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                    ),
                                    child: Text(
                                      _loading
                                          ? 'Please wait...'
                                          : (_registerMode
                                                ? 'Sign up'
                                                : 'Sign in'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => setState(() {
                                        _registerMode = !_registerMode;
                                        _error = null;
                                      }),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.deepPurple,
                                ),
                                child: Text(
                                  _registerMode
                                      ? 'Already have an account? Sign in'
                                      : 'New here? Create an account',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_registerMode) {
        await widget.apiClient.register(
          name: _name.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          persistSession: true,
        );
      } else {
        await widget.apiClient.login(
          login: _login.text.trim(),
          password: _password.text,
          persistSession: _rememberMe,
        );
      }

      widget.onLogin();
    } catch (e) {
      setState(() => _error = friendlyAppErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset flow is not wired up yet.')),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;
}
