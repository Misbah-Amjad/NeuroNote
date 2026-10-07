import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'customwigdets.dart';
import 'login.dart';
import 'signup.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            // ✅ Animated Background Bubbles
            Positioned.fill(
              child: Lottie.asset(
                'assets/animations/Sparkles Animation.json',
                fit: BoxFit.cover,
              ),
            ),
            // ✅ Foreground content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Welcome Text
                  Text(
                    "Welcome",
                    style: GoogleFonts.fredoka(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 19, 184, 167),
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    "           Hi, there......!\nWelcome to NeuroNote",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 0),

                  // ✅ Center Logo / Illustration
                  /*  Container(
                    height: 120,
                    decoration: BoxDecoration(color: Colors.black26),
                    child: Image.asset(
                      "assets/images/logo.png",
                      fit: BoxFit.contain,
                      height: 600, // Add your illustration/logo
                    ),
                  ), */
                  SizedBox(
                    height: 219,
                    width: 300,

                    child: Image.asset(
                      'assets/images/logos.png',
                      fit: BoxFit.cover, // fills height and width, may crop
                    ),
                  ),
                  Text(
                    "Let's start your journey with",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        AmoebaElevatedButton1(
                          width: 250,
                          text: "Log in",
                          color: Colors.white,
                          shadowColor: Colors.tealAccent,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        AmoebaElevatedButton2(
                          width: 250,
                          text: "Sign Up",
                          color: Colors.teal,
                          shadowColor: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignupScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
