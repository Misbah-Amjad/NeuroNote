import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:neuronote/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Image storage
  File? _profileImageFile;
  Uint8List? _profileImageBytes;
  String? _profileImageBase64;
  bool _isImageFromFile = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('userName') ?? 'Guest User';
      _bioController.text =
          prefs.getString('userBio') ?? 'Aspiring Med Student';
      _emailController.text = prefs.getString('userEmail') ?? 'guest@gmail.com';
      _phoneController.text = prefs.getString('userPhone') ?? '';

      // Load image from base64 string
      final imageBase64 = prefs.getString('userImageBase64');
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        try {
          _profileImageBase64 = imageBase64;
          _profileImageBytes = base64Decode(imageBase64);
          _isImageFromFile = false;
        } catch (e) {
          print('Error decoding image: $e');
          _profileImageBase64 = null;
          _profileImageBytes = null;
        }
      } else {
        // Fallback: try file path (legacy)
        final imagePath = prefs.getString('userImage');
        if (!kIsWeb && imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (file.existsSync()) {
            _profileImageFile = file;
            _isImageFromFile = true;
          }
        }
      }
    });
  }

  // ─── Pick Image ──────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? pickedFile;

      if (kIsWeb) {
        // Web: use picker
        pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 80,
        );
      } else {
        // Mobile: use picker
        pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 80,
        );
      }

      if (pickedFile != null) {
        // Read image bytes
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _profileImageBytes = bytes;
          _profileImageBase64 = base64Encode(bytes);
          _profileImageFile = null;
          _isImageFromFile = false;
        });

        // Save immediately to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userImageBase64', _profileImageBase64!);
        await prefs.remove('userImage'); // Remove legacy file path

        _showSnackBar('Image updated successfully!');
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image: ${e.toString()}');
    }
  }

  // ─── Remove Image ────────────────────────────────────────────

  Future<void> _removeImage() async {
    setState(() {
      _profileImageBytes = null;
      _profileImageBase64 = null;
      _profileImageFile = null;
      _isImageFromFile = false;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userImageBase64');
    await prefs.remove('userImage');
    _showSnackBar('Image removed');
  }

  // ─── Save Profile ────────────────────────────────────────────

  Future<void> _saveProfile() async {
    // Validate
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Save text fields
    await prefs.setString('userName', _nameController.text.trim());
    await prefs.setString('userBio', _bioController.text.trim());
    await prefs.setString('userEmail', _emailController.text.trim());
    await prefs.setString('userPhone', _phoneController.text.trim());

    // Image is already saved when picked, but ensure it's saved
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      await prefs.setString('userImageBase64', _profileImageBase64!);
    } else {
      await prefs.remove('userImageBase64');
      await prefs.remove('userImage');
    }

    // Save to AuthService
    await AuthService.saveProfileData({
      'userName': _nameController.text.trim(),
      'userBio': _bioController.text.trim(),
      'userEmail': _emailController.text.trim(),
      'userPhone': _phoneController.text.trim(),
      'userImageBase64': _profileImageBase64 ?? '',
    });

    _showSnackBar('Profile updated successfully!', isSuccess: true);

    // Navigate back with result
    Navigator.pop(context, true);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.teal : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Color teal = Colors.teal;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.teal,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_profileImageBytes != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _removeImage,
              tooltip: 'Remove Image',
            ),
        ],
      ),
      body: Stack(
        children: [
          IgnorePointer(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Lottie.asset(
                    'assets/animations/Sparkles Animation.json',
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                ),
                Container(color: Colors.white.withOpacity(0.05)),
              ],
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  const SizedBox(height: 0),

                  /// Profile Image
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundImage: _getProfileImage(),
                        child:
                            (_profileImageBytes == null &&
                                _profileImageFile == null)
                            ? Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: InkWell(
                          onTap: _showImagePickerDialog,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: teal,
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_profileImageBytes != null)
                    Text(
                      'Tap camera to change image',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),

                  const SizedBox(height: 25),

                  _buildTextField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _bioController,
                    label: "Bio",
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _emailController,
                    label: "Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _phoneController,
                    label: "Phone Number",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text(
                      "Save Changes",
                      style: TextStyle(fontSize: 16),
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

  // ─── Get Profile Image ──────────────────────────────────────

  ImageProvider _getProfileImage() {
    // Priority: bytes (base64) > file > default
    if (_profileImageBytes != null) {
      return MemoryImage(_profileImageBytes!);
    }
    if (!kIsWeb && _profileImageFile != null && _profileImageFile!.existsSync()) {
      return FileImage(_profileImageFile!);
    }
    return const AssetImage('assets/images/profile.jpg') as ImageProvider;
  }

  // ─── Text Field ─────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.teal),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
    );
  }

  // ─── Image Picker Dialog ─────────────────────────────────────

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
