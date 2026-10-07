import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AmoebaElevatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;
  final Color shadowColor;
  final double width;
  final double height;

  const AmoebaElevatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = Colors.teal,
    this.shadowColor = Colors.tealAccent,
    this.width = 180,
    this.height = 60,
  });

  @override
  State<AmoebaElevatedButton> createState() => _AmoebaElevatedButtonState();
}

class _AmoebaElevatedButtonState extends State<AmoebaElevatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _radius(double t, double base, double delta) =>
      base + delta * sin(t * 2 * pi);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              shadowColor: widget.shadowColor.withOpacity(0.6),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_radius(t, 40, 10)),
                  topRight: Radius.circular(_radius(t + 0.25, 20, 10)),
                  bottomLeft: Radius.circular(_radius(t + 0.5, 20, 10)),
                  bottomRight: Radius.circular(_radius(t + 0.75, 40, 10)),
                ),
              ),
            ),
            child: Text(
              widget.text,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AmoebaElevatedButton1 extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;
  final Color shadowColor;
  final double width;
  final double height;

  const AmoebaElevatedButton1({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = Colors.teal,
    this.shadowColor = Colors.tealAccent,
    this.width = 280,
    this.height = 60,
  });

  @override
  State<AmoebaElevatedButton1> createState() => _AmoebaElevatedButtonState1();
}

class _AmoebaElevatedButtonState1 extends State<AmoebaElevatedButton1>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _radius(double t, double base, double delta) =>
      base + delta * sin(t * 2 * pi);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              shadowColor: widget.shadowColor.withOpacity(0.6),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_radius(t, 40, 10)),
                  topRight: Radius.circular(_radius(t + 0.25, 20, 10)),
                  bottomLeft: Radius.circular(_radius(t + 0.5, 20, 10)),
                  bottomRight: Radius.circular(_radius(t + 0.75, 40, 10)),
                ),
              ),
            ),
            child: Text(
              widget.text,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AmoebaElevatedButton2 extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;
  final Color shadowColor;
  final double width;
  final double height;

  const AmoebaElevatedButton2({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = Colors.teal,
    this.shadowColor = Colors.tealAccent,
    this.width = 280,
    this.height = 60,
  });

  @override
  State<AmoebaElevatedButton2> createState() => _AmoebaElevatedButtonState2();
}

class _AmoebaElevatedButtonState2 extends State<AmoebaElevatedButton2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _radius(double t, double base, double delta) =>
      base + delta * sin(t * 2 * pi);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              shadowColor: widget.shadowColor.withOpacity(0.6),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_radius(t, 40, 10)),
                  topRight: Radius.circular(_radius(t + 0.25, 20, 10)),
                  bottomLeft: Radius.circular(_radius(t + 0.5, 20, 10)),
                  bottomRight: Radius.circular(_radius(t + 0.75, 40, 10)),
                ),
              ),
            ),
            child: Text(
              widget.text,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String assetPath;

  const SocialButton({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(40),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white,
        child: Image.asset(assetPath, height: 24),
      ),
    );
  }
}
