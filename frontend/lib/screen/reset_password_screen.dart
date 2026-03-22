import 'package:flutter/material.dart';
import '../style/app_colors_style.dart';
import '../style/app_typography_style.dart';
import '../hooks/reset_password_hook.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validasi password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password harus diisi';
    if (password.length < 8) return 'Password minimal 8 karakter';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Password harus ada huruf besar';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Password harus ada huruf kecil';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Password harus ada angka';
    return null;
  }

  // Function untuk handle reset password
  Future<void> _handleResetPassword() async {
    // Validasi input
    if (_emailController.text.isEmpty) {
      if (!mounted) return;
      _showSnackBar('Email harus diisi!', isError: true);
      return;
    }

    if (!_emailController.text.contains('@')) {
      if (!mounted) return;
      _showSnackBar('Email tidak valid!', isError: true);
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      if (!mounted) return;
      _showSnackBar('Password baru harus diisi!', isError: true);
      return;
    }

    // Validasi password strength
    String? passwordError = _validatePassword(_newPasswordController.text);
    if (passwordError != null) {
      if (!mounted) return;
      _showSnackBar(passwordError, isError: true);
      return;
    }

    // Check password confirmation
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      _showSnackBar('Konfirmasi password tidak sama!', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await Reset_Password_Hook.ResetPassHook(
        email: _emailController.text.trim(),
        password: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar(
          'Password berhasil direset! Silakan login dengan password baru.',
          isError: false,
        );

        // Clear all fields
        _emailController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        // Navigate to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      } else {
        String errorMsg = result['message']?.toString() ?? 'Gagal reset password';
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'Error: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper untuk show snackbar
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [AppColors.cardShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Icon with neon effect
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreenGlow,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: AppColors.iconColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Reset Password',
                    style: AppTypography.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Enter your email and new password',
                    style: AppTypography.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email Input
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Enter your email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // New Password Input
                  _buildTextField(
                    controller: _newPasswordController,
                    hintText: 'Enter new password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureNewPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(() => _obscureNewPassword = !_obscureNewPassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Input
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm new password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Requirements Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.accentGreen,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Password Requirements:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRequirement('Minimal 8 karakter'),
                        _buildRequirement('Mengandung huruf besar (A-Z)'),
                        _buildRequirement('Mengandung huruf kecil (a-z)'),
                        _buildRequirement('Mengandung angka (0-9)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reset Password Button with neon effect
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.accentGreenGlow,
                                blurRadius: 15,
                                spreadRadius: 0,
                              ),
                            ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          disabledBackgroundColor:
                              AppColors.buttonDisabled,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryText,
                                ),
                              )
                            : const Text(
                                'Reset Password',
                                style: AppTypography.button,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(
                          color: AppColors.inputBorder,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: AppTypography.subtitle),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.inputBorder,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Back to Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.secondaryButton,
                        side: BorderSide(
                          color: AppColors.inputBorder,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.accentGreen,
                        size: 20,
                      ),
                      label: const Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ),

                  // Link to Register
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 14,
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

  // Helper method untuk password requirement
  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method untuk TextField dengan neon effect
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTypography.input,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.subtitle,
        prefixIcon: Icon(
          icon,
          color: AppColors.secondaryText,
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
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