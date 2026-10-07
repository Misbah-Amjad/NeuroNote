import 'dart:typed_data';
import 'dart:convert';
import 'auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customwigdets.dart';
import 'navigation.dart';
import 'utils/platform_image_picker.dart';

class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key});

  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<ProfileSetupFlow> {
  double getProfileCompletion() {
    int total = 5;
    int completed = 0;

    if (_avatarBytes != null) completed++;
    if (_nameCtrl.text.trim().isNotEmpty) completed++;
    if (_birthDate != null) completed++;
    if (_gender != null) completed++;
    if (_selectedInterests.isNotEmpty) completed++;

    return completed / total;
  }

  final List<Map<String, dynamic>> _reasons = [
    {"label": "Google", "icon": Icons.search, "color": Colors.red},
    {"label": "Instagram", "icon": Icons.camera_alt, "color": Colors.purple},
    {"label": "Facebook", "icon": Icons.facebook, "color": Colors.blue},
    {"label": "Friends & Family", "icon": Icons.group, "color": Colors.green},
    {
      "label": "YouTube",
      "icon": Icons.play_circle_fill,
      "color": Colors.redAccent,
    },
  ];

  String? _selectedReason;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final _personalFormKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _gender;

  final ImagePicker _picker = ImagePicker();

  final List<String> _availableInterests = [
    'AI',
    'Notes',
    'Quizzes',
    'Flashcards',
    'Progress',
    'Mock Tests',
  ];
  final List<String> _selectedInterests = [];
  final TextEditingController _newInterestCtrl = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _newInterestCtrl.dispose();
    super.dispose();
  }

  Uint8List? _avatarBytes;
  bool _isFinishing = false;

  Future<String> _resolveEmail() async {
    final userData = await AuthService.getUserData();
    final prefs = await SharedPreferences.getInstance();
    return (userData?['email'] ?? prefs.getString('userEmail') ?? '')
        .toString()
        .toLowerCase();
  }

  Map<String, dynamic> _buildProfilePayload(String email) {
    return {
      'userName':
          _nameCtrl.text.trim().isEmpty ? 'User' : _nameCtrl.text.trim(),
      'userBio': 'Student',
      'userEmail': email,
      'userPhone': '+92 300 0000000',
      'userImage': _avatarBytes != null ? 'has_image' : '',
      'userImageBase64':
          _avatarBytes != null ? base64Encode(_avatarBytes!) : '',
      'birthDate': _birthDate != null
          ? '${_birthDate!.day}-${_birthDate!.month}-${_birthDate!.year}'
          : '',
      'gender': _gender ?? '',
      'interests': _selectedInterests,
      'reason': _selectedReason ?? '',
      'profileComplete': true,
    };
  }

  Future<void> _finishSetup({bool skipDefaults = false}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    try {
      final email = await _resolveEmail();
      final payload = skipDefaults
          ? {
              'userName': email.isNotEmpty ? email.split('@')[0] : 'User',
              'userBio': 'Student',
              'userEmail': email,
              'userPhone': '+92 300 0000000',
              'userImage': '',
              'userImageBase64': '',
              'birthDate': '',
              'gender': '',
              'interests': <String>[],
              'reason': '',
              'profileComplete': true,
            }
          : _buildProfilePayload(email);

      // Save locally first so dashboard opens instantly.
      await AuthService.saveProfileData(payload, syncToServer: false);
      await AuthService.markProfileComplete();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );

      // Sync to MySQL in background (don't block Finish button).
      AuthService.saveProfileData(payload);
      if (email.isNotEmpty) {
        AuthService.getProfileFromServer(email);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _pickImage() async {
    final picked = await PlatformImagePicker.pickImage();
    if (picked == null) return;

    Uint8List? bytes;
    if (picked is Uint8List) {
      bytes = picked;
    } else {
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {
        return;
      }
    }

    if (bytes == null) return;

    setState(() {
      _avatarBytes = bytes;
    });
  }

  int getAgeFromDate(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  Future<void> _nextPage() async {
    if (_currentIndex == 1) {
      if (!_personalFormKey.currentState!.validate()) {
        return;
      }
    }

    if (_currentIndex < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      await _finishSetup();
    }
  }

  Future<void> _skipToEnd() async {
    await _finishSetup(skipDefaults: true);
  }

  void _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Widget _buildTopProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final active = _currentIndex == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: active ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? Colors.teal : Colors.teal.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _stepAvatar() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 18),
        Text(
          "Add a profile photo",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This helps friends recognize you. You can change it later.",
          style: GoogleFonts.poppins(color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 70,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _avatarBytes != null
                ? MemoryImage(_avatarBytes!)
                : const AssetImage('assets/images/lo.png') as ImageProvider,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: _pickImage,
          child: Text(
            "Choose photo",
            style: GoogleFonts.poppins(
              color: Colors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepPersonalInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _personalFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Tell us about yourself",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: "Full name",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _birthDate == null
                          ? "Select birthdate"
                          : "${_birthDate!.day}-${_birthDate!.month}-${_birthDate!.year}  (${getAgeFromDate(_birthDate!).toString()} yrs)",
                      style: GoogleFonts.poppins(
                        color: _birthDate == null
                            ? Colors.grey
                            : Colors.black87,
                      ),
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Male', 'Female', 'Other'].map((g) {
                final selected = _gender == g;
                return ChoiceChip(
                  label: Text(g),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _gender = g;
                    });
                  },
                  selectedColor: Colors.teal.shade300,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepReasons() {
    final List<Map<String, dynamic>> reasons = [
      {
        "label": "Social Media",
        "icons": [Icons.facebook, Icons.camera_alt, Icons.music_note],
      },
      {
        "label": "Google Search",
        "icons": [Icons.search],
      },
      {
        "label": "YouTube",
        "icons": [Icons.play_circle_fill],
      },
      {
        "label": "App Store",
        "icons": [Icons.apps],
      },
      {
        "label": "Friends / Family",
        "icons": [Icons.family_restroom],
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Lastly, how did you hear about NeuroNote?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This helps us understand where our users come from.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.builder(
              itemCount: reasons.length,
              itemBuilder: (context, index) {
                final reason = reasons[index];
                final isSelected = _selectedReason == reason['label'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReason = reason['label'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.teal : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: (reason['icons'] as List<IconData>)
                              .map(
                                (icon) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    icon,
                                    size: 28,
                                    color: Colors.black87,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            reason['label'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.teal,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInterests() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Choose Interests",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pick a few topics you care about â€” helps personalize your feed.",
            style: GoogleFonts.poppins(color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final selected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
                selectedColor: Colors.teal.shade300,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newInterestCtrl,
                  decoration: InputDecoration(
                    hintText: "Add custom interest",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AmoebaElevatedButton2(
                onPressed: () {
                  final text = _newInterestCtrl.text.trim();
                  if (text.isEmpty) return;

                  setState(() {
                    if (!_availableInterests.contains(text)) {
                      _availableInterests.add(text);
                    }
                    _selectedInterests.add(text);

                    _newInterestCtrl.clear();
                  });
                },
                text: 'Add',
                width: 100,
                height: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepReview() {
    final progress = getProfileCompletion();
    final percentage = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Preparing a personalized page for you...",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Please wait...",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          CircularPercentIndicator(
            radius: 80.0,
            lineWidth: 10.0,
            animation: true,
            percent: progress,
            center: Text(
              "$percentage%",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 28.0,
                color: Colors.black87,
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.teal,
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            "This might take a few moments.\nGet ready for an amazing study experience!",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "You can change these later in profile settings.",
            style: GoogleFonts.poppins(color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
              repeat: true,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopProgress(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: [
                      _stepAvatar(),
                      _stepPersonalInfo(),
                      _stepReasons(),
                      _stepInterests(),
                      _stepReview(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AmoebaElevatedButton1(
                        onPressed: () {
                          if (_currentIndex == 0) {
                            _skipToEnd();
                          } else {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        text: _currentIndex == 0 ? 'Skip' : 'Back',
                        color: Colors.white,
                        height: 44,
                        width: 120,
                      ),
                      AmoebaElevatedButton2(
                        onPressed: _isFinishing ? () {} : () => _nextPage(),
                        text: _isFinishing
                            ? 'Saving...'
                            : (_currentIndex == 4 ? 'Finish' : 'Next'),
                        width: 120,
                        height: 44,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
