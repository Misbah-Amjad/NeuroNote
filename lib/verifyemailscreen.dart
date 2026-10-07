import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isVerified = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    checkEmailVerified();
  }

  // 🔥 Check if email is verified
  Future<void> checkEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    setState(() {
      isVerified = user?.emailVerified ?? false;
    });

    if (isVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, size: 90, color: Colors.teal),
              SizedBox(height: 20),
              Text(
                "A verification email has been sent\nto your inbox.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.teal),
              ),
              SizedBox(height: 20),

              // 🔄 Refresh Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  setState(() => isLoading = true);
                  await checkEmailVerified();
                  setState(() => isLoading = false);
                },
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("I Verified My Email"),
              ),

              SizedBox(height: 15),

              // 🔁 Resend Email Button
              TextButton(
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  await user?.sendEmailVerification();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Verification email re-sent!"),
                      backgroundColor: Colors.teal,
                    ),
                  );
                },
                child: Text("Resend Email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
