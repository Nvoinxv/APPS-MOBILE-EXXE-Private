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
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Step: 1 = Request OTP, 2 = Verify OTP, 3 = Reset Password
  int _currentStep = 1;

  // Simpan email & OTP untuk dikirim ke step berikutnya
  String _submittedEmail = '';
  String _verifiedOtp = '';

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validasi ───────────────────────────────────────────────────────────────
  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password harus diisi';
    if (password.length < 10) return 'Password minimal 10 karakter';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Harus ada huruf kapital';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Harus ada angka';
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]')))
      return 'Harus ada karakter spesial (!@#\$%^&*...)';
    return null;
  }

  // ── Step 1: Request OTP ───────────────────────────────────────────────────
  Future<void> _handleRequestOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Email harus diisi!', isError: true);
      return;
    }
    if (!_emailController.text.contains('@')) {
      _showSnackBar('Format email tidak valid!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Reset_Password_Hook.requestOtp(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _submittedEmail = _emailController.text.trim();
        setState(() => _currentStep = 2);
        _showSnackBar('Kode OTP telah dikirim ke email kamu', isError: false);
      } else {
        final msg = result['message'];
        String errorText = 'Gagal mengirim OTP';
        if (msg is Map && msg['detail'] != null) {
          errorText = msg['detail'].toString();
        } else if (msg is String) {
          errorText = msg;
        }
        _showSnackBar(errorText, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      _showSnackBar('Kode OTP harus diisi!', isError: true);
      return;
    }
    if (_otpController.text.trim().length != 6) {
      _showSnackBar('Kode OTP harus 6 digit!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Reset_Password_Hook.verifyOtp(
        email: _submittedEmail,
        otpCode: _otpController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _verifiedOtp = _otpController.text.trim();
        setState(() => _currentStep = 3);
        _showSnackBar('OTP valid! Silakan buat password baru', isError: false);
      } else {
        final msg = result['message'];
        String errorText = 'OTP tidak valid';
        if (msg is Map && msg['detail'] != null) {
          errorText = msg['detail'].toString();
        } else if (msg is String) {
          errorText = msg;
        }
        _showSnackBar(errorText, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 3: Confirm Reset Password ────────────────────────────────────────
  Future<void> _handleConfirmReset() async {
    final passwordError = _validatePassword(_newPasswordController.text);
    if (passwordError != null) {
      _showSnackBar(passwordError, isError: true);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Konfirmasi password tidak sama!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Reset_Password_Hook.confirmReset(
        email: _submittedEmail,
        otpCode: _verifiedOtp,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar(
          'Password berhasil diperbarui! Silakan login.',
          isError: false,
        );
        _emailController.clear();
        _otpController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        });
      } else {
        final msg = result['message'];
        String errorText = 'Gagal reset password';
        if (msg is Map && msg['detail'] != null) {
          errorText = msg['detail'].toString();
        } else if (msg is String) {
          errorText = msg;
        }
        _showSnackBar(errorText, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helper ─────────────────────────────────────────────────────────────────
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                  // Icon
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

                  // Step Indicator
                  _buildStepIndicator(),
                  const SizedBox(height: 24),

                  // Title & Subtitle per step
                  Text(
                    _stepTitle(),
                    style: AppTypography.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stepSubtitle(),
                    style: AppTypography.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Content per step
                  if (_currentStep == 1) _buildStep1(),
                  if (_currentStep == 2) _buildStep2(),
                  if (_currentStep == 3) _buildStep3(),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: const [
                      Expanded(child: Divider(color: AppColors.inputBorder, thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: AppTypography.subtitle),
                      ),
                      Expanded(child: Divider(color: AppColors.inputBorder, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Back to Login
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.secondaryButton,
                        side: BorderSide(color: AppColors.inputBorder, width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.accentGreen, size: 20),
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

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account? ',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
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

  // ── Step Indicator ─────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final step = index + 1;
        final isActive = step == _currentStep;
        final isDone = step < _currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 32 : 24,
              height: isActive ? 32 : 24,
              decoration: BoxDecoration(
                color: isDone || isActive
                    ? AppColors.accentGreen
                    : AppColors.inputBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppColors.accentGreen
                      : AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : Text(
                        '$step',
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.black : AppColors.secondaryText,
                        ),
                      ),
              ),
            ),
            if (index < 2)
              Container(
                width: 40,
                height: 2,
                color: step < _currentStep
                    ? AppColors.accentGreen
                    : AppColors.inputBorder,
              ),
          ],
        );
      }),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 1: return 'Reset Password';
      case 2: return 'Verifikasi OTP';
      case 3: return 'Password Baru';
      default: return '';
    }
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case 1: return 'Masukkan email untuk menerima kode OTP';
      case 2: return 'Kode OTP telah dikirim ke $_submittedEmail';
      case 3: return 'Buat password baru untuk akunmu';
      default: return '';
    }
  }

  // ── Step 1 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          hintText: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Kirim OTP',
          onPressed: _handleRequestOtp,
        ),
      ],
    );
  }

  // ── Step 2 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      children: [
        _buildTextField(
          controller: _otpController,
          hintText: 'Masukkan 6 digit OTP',
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        // Resend OTP
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : () {
              setState(() => _otpController.clear());
              _handleRequestOtp();
            },
            child: const Text(
              'Kirim ulang OTP',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          label: 'Verifikasi OTP',
          onPressed: _handleVerifyOtp,
        ),
      ],
    );
  }

  // ── Step 3 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      children: [
        _buildTextField(
          controller: _newPasswordController,
          hintText: 'Password baru',
          icon: Icons.lock_outline,
          obscureText: _obscureNewPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.secondaryText,
            ),
            onPressed: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          hintText: 'Konfirmasi password baru',
          icon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.secondaryText,
            ),
            onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ),
        const SizedBox(height: 12),

        // Password Requirements
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
                  Icon(Icons.info_outline, size: 16, color: AppColors.accentGreen),
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
              _buildRequirement('Minimal 10 karakter'),
              _buildRequirement('Minimal 1 huruf kapital (A-Z)'),
              _buildRequirement('Minimal 1 angka (0-9)'),
              _buildRequirement('Minimal 1 karakter spesial (!@#\$%^&*...)'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Simpan Password Baru',
          onPressed: _handleConfirmReset,
        ),
      ],
    );
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────────
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: _isLoading
            ? []
            : [BoxShadow(color: AppColors.accentGreenGlow, blurRadius: 15)],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryButton,
            disabledBackgroundColor: AppColors.buttonDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryText),
                )
              : Text(label, style: AppTypography.button),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: AppColors.secondaryText),
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
        prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
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
          borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
        ),
      ),
    );
  }
}