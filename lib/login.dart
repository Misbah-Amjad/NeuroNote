import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'backend_service.dart';
import 'customwigdets.dart';
import 'signup.dart';
import 'forgotpassword.dart';
import 'navigation.dart';
import 'profile_setup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool emailFocused = false;
  bool passwordFocused = false;
  bool isLoading = false;
  bool rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(() {
      setState(() => emailFocused = emailFocus.hasFocus);
    });
    passwordFocus.addListener(() {
      setState(() => passwordFocused = passwordFocus.hasFocus);
    });
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      rememberMe = prefs.getBool('rememberMe') ?? false;
      if (rememberMe) {
        emailController.text = prefs.getString('email') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _saveRememberMe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('email', emailController.text.trim());
      await prefs.setString('password', passwordController.text.trim());
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('email');
      await prefs.remove('password');
    }
  }

  bool _isEmailValid(String email) {
    return email.contains('@') && email.contains('gmail.com');
  }

  void _login() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showCustomSnackBar("Please enter both email and password");
      return;
    }

    if (!_isEmailValid(email)) {
      _showCustomSnackBar("Email incorrect");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.login(email, password);

      if (result['success'] == true) {
        final isComplete = await AuthService.completeLoginFlow(email, result);

        // 1) Restore this user's work from MySQL (flashcards, quizzes, summaries, progress)
        await BackendService.syncAllFromServer(emailOverride: email);
        // 2) Upload anything that was only on device
        await BackendService.pushLocalContentToServer(emailOverride: email);
        await BackendService.saveProgress(emailOverride: email);

        await _saveRememberMe();
        _showCustomSnackBar("Login Successful!", success: true);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                isComplete ? const MainNavigation() : const ProfileSetupFlow(),
          ),
        );
      } else {
        _showCustomSnackBar(result['message'] ?? "Login failed");
      }
    } catch (e) {
      _showCustomSnackBar("Something went wrong");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showCustomSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: success ? Colors.teal : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    child: Text(
                      "Welcome Back!",
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
                      "Login to continue",
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
                  // Password Field with toggle
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
                            hintText: "Password",
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
                  // Remember Me Checkbox
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: rememberMe,
                          activeColor: Colors.teal,
                          onChanged: (value) {
                            setState(() {
                              rememberMe = value ?? false;
                            });
                          },
                        ),
                        Text(
                          "Remember Me",
                          style: GoogleFonts.poppins(
                            color: Colors.teal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 117),
                    child: InkWell(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password..?',
                          style: GoogleFonts.poppins(color: Colors.teal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Login Button
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : AmoebaElevatedButton(onPressed: _login, text: 'Login'),
                  const SizedBox(height: 20),
                  // Sign up link
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Don’t have an account..? Sign Up',
                        style: TextStyle(color: Colors.teal),
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
