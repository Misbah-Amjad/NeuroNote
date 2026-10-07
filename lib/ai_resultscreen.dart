import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AIResultScreen extends StatelessWidget {
  final String result;
  final String title;

  const AIResultScreen({super.key, required this.result, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(result, style: GoogleFonts.poppins(fontSize: 16)),
        ),
      ),
    );
  }
}
