import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ingridio/screens/personalize_screen.dart';
import 'package:ingridio/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color _primary = Color(0xFF9D4300);
  static const Color _primaryContainer = Color(0xFFF97316);
  static const Color _background = Color(0xFFFFF8F5);
  static const Color _surfaceContainerLow = Color(0xFFFFF1E9);
  static const Color _onSurface = Color(0xFF2F1400);
  static const Color _onSurfaceVariant = Color(0xFF8C7164);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordHidden = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Email and password are required.');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthService.instance.signUp(
        email: email,
        password: password,
        displayName: name.isEmpty ? null : name,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PersonalizeScreen()),
        (Route<dynamic> route) => false,
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      _snack(AuthService.describeAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        foregroundColor: _onSurface,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Create your account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to save recipes, build your pantry, and keep your preferences.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 15,
                      color: _onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Field(
                    label: 'Display name (optional)',
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    obscureText: false,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    obscureText: false,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Password (min 6 chars)',
                    icon: Icons.lock_outline_rounded,
                    controller: _passwordController,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: _passwordHidden,
                    suffix: IconButton(
                      icon: Icon(
                        _passwordHidden
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _onSurfaceVariant,
                      ),
                      onPressed: () => setState(
                        () => _passwordHidden = !_passwordHidden,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const RadialGradient(
                          center: Alignment.center,
                          radius: 1.5,
                          colors: <Color>[_primaryContainer, _primary],
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x339D4300),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Create account',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Already have an account? Sign in',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        color: _primary,
                        fontWeight: FontWeight.w600,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.icon,
    required this.controller,
    required this.keyboardType,
    required this.obscureText,
    this.suffix,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _SignupScreenState._onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            color: _SignupScreenState._onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _SignupScreenState._onSurfaceVariant),
            suffixIcon: suffix,
            filled: true,
            fillColor: _SignupScreenState._surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
