import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'customwigdets.dart';
import 'landingpage.dart';


class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> walkthroughData = [
    {
      "image": "assets/images/walk1.png",
      "title": "Welcome to NeuroNote — Study Smarter, Not Harder..",
      "desc":
          "Your AI-powered study companion that helps you stay focused and organized.",
    },
    {
      "image": "assets/images/walk2.png",
      "title": "Scan & Summarize Notes",
      "desc":
          "Take a picture of your notes or upload them and get instant smart summaries.",
    },
    {
      "image": "assets/images/walk3.png",
      "title": "AI Quiz Generator",
      "desc":
          "Turn your notes into quizzes to test yourself before the big exam.",
    },
    {
      "image": "assets/images/walk4.png",
      "title": "Track Your Progress",
      "desc":
          "Get personalized reports, insights, and stay motivated in your journey.",
    },
  ];

  // ignore: unused_element
  /* void _nextPage() {
    if (_currentIndex < walkthroughData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // ✅ Go to Dashboard / Home
      debugPrint("Walkthrough Finished → Navigate to Dashboard");
    }
  } */
  void _nextPage() {
    if (_currentIndex < walkthroughData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // ✅ Go to Dashboard / Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LandingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ PageView
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageController,
                itemCount: walkthroughData.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final data = walkthroughData[index];
                  return Column(
                    children: [
                      // ✅ Background with Image
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(90),
                              bottomRight: Radius.circular(90),
                            ),
                          ),

                          child: Padding(
                            padding: const EdgeInsets.all(00.0),
                            /* child: ClipRRect(
                              borderRadius: BorderRadiusGeometry.only(
                                bottomLeft: Radius.circular(90),
                                bottomRight: Radius.circular(90),
                              ),
                              child: Image.asset(
                                data["image"]!,
                                fit: BoxFit.cover,
                              ),
                              
                            ), */
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 🔹 Lottie Animation in background
                                Lottie.asset(
                                  "assets/animations/Sparkles Animation.json", // put your lottie file here
                                  fit: BoxFit.cover,
                                  repeat: true,
                                ),

                                // 🔹 Your existing Image
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(90),
                                    bottomRight: Radius.circular(90),
                                  ),
                                  child: Image.asset(
                                    data["image"]!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ✅ Title + Description
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              Text(
                                data["title"]!,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                data["desc"]!,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ✅ Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                walkthroughData.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.teal
                        : Colors.teal.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip Button
                  /*  TextButton(
                    onPressed: () {
                      debugPrint("Skip clicked → Navigate to Dashboard");
                    },
                    child: Text(
                      "Skip",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.teal.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ), */
                  /*  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: AmoebaElevatedButton1(
                      onPressed: () {
                        debugPrint("Skip clicked → Navigate to Dashboard");
                      },
                      text: 'Skip',
                      color: Colors.white,
                      height: 40,
                      width: 135,
                    ),
                  ), */
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: AmoebaElevatedButton1(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LandingScreen(),
                          ),
                        );
                      },
                      text: 'Skip',
                      color: Colors.white,
                      height: 40,
                      width: 135,
                    ),
                  ),

                  // Continue Button
                  /*   ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentIndex == walkthroughData.length - 1
                          ? "Get Started"
                          : "Continue",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ), */
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: AmoebaElevatedButton2(
                      onPressed: _nextPage, // ✅ added your next page logic here
                      text: _currentIndex == walkthroughData.length - 1
                          ? "Let's Go" // ✅ change text dynamically
                          : "Continue",

                      width: 135,
                      height: 40,
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
