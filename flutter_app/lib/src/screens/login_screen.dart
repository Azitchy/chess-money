import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.onLogin,
    required this.onBypassLogin,
  });

  final ApiClient apiClient;
  final VoidCallback onLogin;
  final VoidCallback onBypassLogin;

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
    const blue = Color(0xFF49A6F4);
    const lavender = Color(0xFF7B74F7);
    const deepPurple = Color(0xFF4D3FD9);
    const pageBg = Color(0xFFF4F9FF);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          const _LoginBackdrop(),
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
                      const _AvatarBadge(),
                      const SizedBox(height: 18),
                      Text(
                        _registerMode ? 'Create account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2456A6),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _registerMode
                            ? 'Set up your Chess Money profile'
                            : 'Sign in to continue to your wallet and matches',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6D87B7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
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
                                _PillTextField(
                                  controller: _name,
                                  label: 'Full name',
                                  icon: Icons.badge_outlined,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                _PillTextField(
                                  controller: _username,
                                  label: 'Username',
                                  icon: Icons.person_outline,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                _PillTextField(
                                  controller: _email,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                _PillTextField(
                                  controller: _login,
                                  label: 'Username or email',
                                  icon: Icons.person_outline,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _PillTextField(
                                controller: _password,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: true,
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              if (!_registerMode)
                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 0.95,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: _loading
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _rememberMe = value ?? true;
                                                });
                                              },
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        activeColor: blue,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Color(0xFF6D87B7),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _forgotPassword,
                                      style: TextButton.styleFrom(
                                        foregroundColor: blue,
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
                                      colors: [blue, lavender],
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
                                  foregroundColor: deepPurple,
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
                              if (kDebugMode) ...[
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : widget.onBypassLogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1F6FEB),
                                  ),
                                  child: const Text(
                                    'Skip login for demo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
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
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
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

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF5FF), Color(0xFFF8FBFF)],
            ),
          ),
        ),
        Positioned(
          top: -68,
          left: -56,
          child: _CircleBlob(size: 220, color: Color(0xFF61B6FF)),
        ),
        Positioned(
          top: -88,
          right: -84,
          child: _CircleBlob(size: 270, color: Color(0xFF7B74F7)),
        ),
        Positioned(
          left: -28,
          right: -28,
          bottom: -26,
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFF49A6F4),
              borderRadius: BorderRadius.circular(34),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleBlob extends StatelessWidget {
  const _CircleBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF44A7F5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 68, color: Colors.white),
    );
  }
}

class _PillTextField extends StatelessWidget {
  const _PillTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: Color(0xFF264D7E),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF5D8FDE)),
        filled: true,
        fillColor: const Color(0xFFF4F8FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFD9E6FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFD9E6FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFF49A6F4), width: 1.6),
        ),
      ),
    );
  }
}
