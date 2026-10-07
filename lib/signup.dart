import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'auth_service.dart';
import 'customwigdets.dart';
import 'login.dart';
import 'profile_setup.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();

  bool emailFocused = false;
  bool passwordFocused = false;
  bool confirmPasswordFocused = false;
  bool isLoading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasMinLength = false;
  bool _hasSpecialChar = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(() {
      setState(() => emailFocused = emailFocus.hasFocus);
    });
    passwordFocus.addListener(() {
      setState(() => passwordFocused = passwordFocus.hasFocus);
    });
    confirmPasswordFocus.addListener(() {
      setState(() => confirmPasswordFocused = confirmPasswordFocus.hasFocus);
    });

    passwordController.addListener(_checkPasswordRules);
  }

  void _checkPasswordRules() {
    final password = passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 6;
      _hasSpecialChar = RegExp(r'[!@#\$&*~]').hasMatch(password);
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    return _hasMinLength && _hasSpecialChar && _hasUppercase && _hasLowercase;
  }

  bool _isEmailValid(String email) {
    return email.contains('@') && email.endsWith('gmail.com');
  }

  void _signUp() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }

    if (!_isEmailValid(email)) {
      _showSnackBar("Incorrect email");
      return;
    }

    if (!_isPasswordValid(password)) {
      _showSnackBar(
        "Password must be at least 6 characters, include uppercase, lowercase, and a special character (!@#\$&*~)",
      );
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.signUp(email, password);

      if (result['success'] == true) {
        await AuthService.ensureUserSession(email);

        final loginResult = await AuthService.login(email, password);
        if (loginResult['success'] == true) {
          await AuthService.saveUserData({
            'email': email,
            'name': loginResult['name'] ?? email.split('@')[0],
            'uid': loginResult['uid'] ?? '',
            'loggedIn': true,
          });

          _showSnackBar("Account created successfully!", success: true);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupFlow()),
          );
          return;
        }

        _showSnackBar("Account created — please log in", success: true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _showSnackBar(result['message'] ?? "Sign up failed");
      }
    } catch (e) {
      _showSnackBar("Something went wrong");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: success ? Colors.green : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool isValid, {double fontSize = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          color: isValid ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: isValid ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            child: Container(
              height: size.height,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 38),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    child: Text(
                      "Welcome Students...!",
                      style: GoogleFonts.fredoka(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      "Sign Up To Get Started",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Email Field
                  FadeInLeft(
                    delay: const Duration(milliseconds: 400),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: size.width * 0.8,
                        decoration: BoxDecoration(
                          color: emailFocused
                              ? const Color.fromARGB(255, 227, 252, 250)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          focusNode: emailFocus,
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: "Email",
                            prefixIcon: Icon(Icons.email, color: Colors.teal),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Password Field
                  FadeInRight(
                    delay: const Duration(milliseconds: 500),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: size.width * 0.8,
                        decoration: BoxDecoration(
                          color: passwordFocused
                              ? const Color.fromARGB(255, 227, 252, 250)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          focusNode: passwordFocus,
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Create Password",
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.teal,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.teal,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
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
                  ),
                  const SizedBox(height: 10),
                  // Confirm Password Field
                  FadeInRight(
                    delay: const Duration(milliseconds: 600),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: size.width * 0.8,
                        decoration: BoxDecoration(
                          color: confirmPasswordFocused
                              ? const Color.fromARGB(255, 227, 252, 250)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          focusNode: confirmPasswordFocus,
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: "Confirm Password",
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.teal,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.teal,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
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
                  ),
                  const SizedBox(height: 10),
                  // Live password rules
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPasswordRule(
                        "At least 6 characters",
                        _hasMinLength,
                        fontSize: 12,
                      ),
                      _buildPasswordRule(
                        "Contains uppercase letter",
                        _hasUppercase,
                        fontSize: 12,
                      ),
                      _buildPasswordRule(
                        "Contains lowercase letter",
                        _hasLowercase,
                        fontSize: 12,
                      ),
                      _buildPasswordRule(
                        "Contains special character (!@#\$&*~)",
                        _hasSpecialChar,
                        fontSize: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Sign Up Button
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : AmoebaElevatedButton(
                          onPressed: _signUp,
                          text: 'Sign Up',
                        ),
                  const SizedBox(height: 10),
                  // Login link
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Already Have an Account..? Login",
                        style: GoogleFonts.poppins(color: Colors.teal),
                      ),
                    ),
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
