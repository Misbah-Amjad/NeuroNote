import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'auth_service.dart';
import 'customwigdets.dart';
import 'login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode newPasswordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();

  bool emailFocused = false;
  bool newPasswordFocused = false;
  bool confirmPasswordFocused = false;
  bool isLoading = false;
  bool emailVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _verifiedEmail = '';

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(() {
      setState(() => emailFocused = emailFocus.hasFocus);
    });
    newPasswordFocus.addListener(() {
      setState(() => newPasswordFocused = newPasswordFocus.hasFocus);
    });
    confirmPasswordFocus.addListener(() {
      setState(() => confirmPasswordFocused = confirmPasswordFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    emailFocus.dispose();
    newPasswordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.teal : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Please enter your email');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.forgotPassword(email);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          emailVerified = true;
          _verifiedEmail = email;
        });
        _showSnackBar('Email verified. Set your new password.', success: true);
      } else {
        _showSnackBar(result['message'] ?? 'Email not found');
      }
    } catch (e) {
      _showSnackBar('Something went wrong');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Please enter new password');
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.resetPassword(
        email: _verifiedEmail,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar(
          result['message'] ?? 'Password changed successfully',
          success: true,
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        });
      } else {
        _showSnackBar(result['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      _showSnackBar('Something went wrong');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    final size = MediaQuery.of(context).size;

    return FadeInLeft(
      delay: const Duration(milliseconds: 400),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size.width * 0.8,
          decoration: BoxDecoration(
            color: isFocused
                ? const Color.fromARGB(255, 227, 252, 250)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            focusNode: focusNode,
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.teal),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.teal,
                      ),
                      onPressed: onToggleObscure,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
              animate: true,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Text(
                    emailVerified ? 'Set New Password' : 'Forgot Password?',
                    style: GoogleFonts.fredoka(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emailVerified
                        ? 'Enter a new password for\n$_verifiedEmail'
                        : "Enter your registered email\nto reset your password.",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (!emailVerified) ...[
                    _buildTextField(
                      controller: emailController,
                      focusNode: emailFocus,
                      isFocused: emailFocused,
                      hint: 'Email',
                      icon: Icons.email,
                    ),
                    const SizedBox(height: 30),
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.teal)
                        : AmoebaElevatedButton2(
                            onPressed: _verifyEmail,
                            text: 'Continue',
                            height: 50,
                            width: 195,
                          ),
                  ] else ...[
                    _buildTextField(
                      controller: newPasswordController,
                      focusNode: newPasswordFocus,
                      isFocused: newPasswordFocused,
                      hint: 'New Password',
                      icon: Icons.lock,
                      obscure: _obscureNewPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: confirmPasswordController,
                      focusNode: confirmPasswordFocus,
                      isFocused: confirmPasswordFocused,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirmPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 30),
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.teal)
                        : AmoebaElevatedButton2(
                            onPressed: _resetPassword,
                            text: 'Change Password',
                            height: 50,
                            width: 195,
                          ),
                  ],
                  const SizedBox(height: 20),
                  AmoebaElevatedButton1(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    text: 'Back To Login',
                    color: Colors.white,
                    height: 50,
                    width: 195,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
