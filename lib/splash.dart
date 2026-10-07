import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'navigation.dart';
import 'walkthroughscreens.dart';
import 'profile_setup.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final isLoggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      bool profileComplete = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final userData = await AuthService.getUserData();
        if (userData?['uid'] != null) {
          await prefs.setString('uid', userData!['uid'].toString());
        }
        final email = (userData?['email'] ?? prefs.getString('userEmail') ?? '')
            .toString()
            .toLowerCase();
        if (email.isNotEmpty) {
          await AuthService.ensureUserSession(email);
          final serverProfile = await AuthService.getProfileFromServer(email);
          await AuthService.ensureProfileOnServer(email);
          profileComplete = await AuthService.resolveProfileComplete(
            serverProfile: serverProfile,
          );
        } else {
          profileComplete = await AuthService.isProfileComplete();
        }
      } catch (_) {
        profileComplete = await AuthService.isProfileComplete();
      }

      if (!mounted) return;

      await BackendService.syncAllFromServer();
      await BackendService.pushLocalContentToServer();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => profileComplete
              ? const MainNavigation()
              : const ProfileSetupFlow(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WalkthroughScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInDown(
                  child: Image.asset('assets/images/logos.png', width: 400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
