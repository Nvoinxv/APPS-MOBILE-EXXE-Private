import 'package:flutter/material.dart';
import '../style/app_colors_style.dart';
import '../style/app_typography_style.dart';
import '../hooks/register_hook.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController            = TextEditingController();
  final TextEditingController _emailController           = TextEditingController();
  final TextEditingController _passwordController        = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading              = false;
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;

  bool _isStrongPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,}$',
    );
    return regex.hasMatch(password);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Semua field harus diisi!', isError: true);
      return;
    }
    if (!_emailController.text.contains('@')) {
      _showSnackBar('Email tidak valid!', isError: true);
      return;
    }
    if (!_isStrongPassword(_passwordController.text)) {
      _showSnackBar(
        'Password minimal 10 karakter dan wajib ada huruf besar, huruf kecil, angka, dan simbol!',
        isError: true,
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Password dan Konfirmasi Password tidak sama!', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await registerHook(
        name:     _nameController.text.trim(),
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      _showSnackBar(
        result['message'] ?? 'Registrasi berhasil! Silakan verifikasi OTP.',
        isError: false,
      );

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/otp');
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 3),
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color:        AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow:    [AppColors.cardShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  Container(
                    width:   80,
                    height:  80,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:        AppColors.accentGreenGlow,
                          blurRadius:   10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo_exxe_no_background.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────────
                  const Text(
                    'Welcome to EXXE.LAB',
                    style:     AppTypography.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Create your account to get started',
                    style:     AppTypography.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Form fields ───────────────────────────────────────────
                  _buildTextField(
                    controller: _nameController,
                    hintText:   'Enter your name',
                    icon:       Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller:   _emailController,
                    hintText:     'Enter your email',
                    icon:         Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller:  _passwordController,
                    hintText:    'Enter your password',
                    icon:        Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller:  _confirmPasswordController,
                    hintText:    'Confirm your password',
                    icon:        Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '* Role akan otomatis di-set sebagai GENERAL',
                      style: TextStyle(
                        fontSize:  12,
                        color:     AppColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Register button ───────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color:        AppColors.accentGreenGlow,
                                blurRadius:   15,
                                spreadRadius: 0,
                              ),
                            ],
                    ),
                    child: SizedBox(
                      width:  double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:        AppColors.primaryButton,
                          disabledBackgroundColor: AppColors.buttonDisabled,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width:  20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryText,
                                ),
                              )
                            : const Text('Continue', style: AppTypography.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Divider ───────────────────────────────────────────────
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(color: AppColors.inputBorder, thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: AppTypography.subtitle),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.inputBorder, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Google button (UI only — coming soon) ─────────────────
                  SizedBox(
                    width:  double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: null, // disabled sampai Google Sign-In siap di production
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.googleButton,
                        disabledBackgroundColor:
                            AppColors.googleButton.withOpacity(0.5),
                        side: BorderSide(
                          color: AppColors.inputBorder.withOpacity(0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        width:  20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, color: Colors.white54),
                      ),
                      label: const Text(
                        'Continue with Google (Coming Soon)',
                        style: TextStyle(
                          color:      Colors.white54,
                          fontSize:   14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // ── Link ke Login ─────────────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color:    AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: TextButton.styleFrom(
                          padding:       const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize:   Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color:      AppColors.accentGreen,
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool           obscureText  = false,
    Widget?        suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller:   controller,
      obscureText:  obscureText,
      keyboardType: keyboardType,
      style:        AppTypography.input,
      decoration: InputDecoration(
        hintText:  hintText,
        hintStyle: AppTypography.subtitle,
        prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
        suffixIcon: suffixIcon,
        filled:    true,
        fillColor: AppColors.inputBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.accentGreen,
            width: 2,
          ),
        ),
      ),
    );
  }
}