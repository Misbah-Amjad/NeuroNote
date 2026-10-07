import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:neuronote/auth_service.dart';
import 'package:neuronote/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editprofile.dart';
import 'navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = 'Guest User';
  String userBio = 'Aspiring Med Student';
  String userEmail = 'guest@gmail.com';
  String userPhone = '';
  String birthDate = 'Not set';
  String gender = 'Not set';
  String interests = 'Not set';
  String reason = 'Not set';

  Uint8List? _profileImageBytes;
  File? _profileImageFile;
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _updateLocalFields(prefs);

      final email = (prefs.getString('userEmail') ?? userEmail).toLowerCase();
      if (email.isNotEmpty && email != 'guest@gmail.com') {
        final serverProfile = await AuthService.getProfileFromServer(email);
        if (serverProfile != null) {
          _updateLocalFields(prefs);
        }
      }
    } catch (e) {
      debugPrint('Error in _loadProfileData: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateLocalFields(SharedPreferences prefs) {
    userName = prefs.getString('userName') ?? 'Guest User';
    userBio = prefs.getString('userBio') ?? 'Aspiring Med Student';
    userEmail = prefs.getString('userEmail') ?? 'guest@gmail.com';
    userPhone = prefs.getString('userPhone') ?? '';
    birthDate = _displayOrNotSet(prefs.getString('birthDate'));
    gender = _displayOrNotSet(prefs.getString('gender'));

    final reasonVal = prefs.getString('reason');
    reason = _displayOrNotSet(reasonVal);

    final interestsList = prefs.getStringList('interests');
    if (interestsList != null && interestsList.isNotEmpty) {
      interests = interestsList.join(', ');
    } else {
      final interestsStr = prefs.getString('interests_str');
      interests = _displayOrNotSet(interestsStr);
    }

    _profileImageUrl = null;
    _profileImageBytes = null;
    _profileImageFile = null;

    final imageUrl = prefs.getString('userImage');
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl.startsWith('http')) {
      _profileImageUrl = imageUrl;
      return;
    }

    final imageBase64 = prefs.getString('userImageBase64');
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        _profileImageBytes = base64Decode(imageBase64);
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
      return;
    }

    if (!kIsWeb && imageUrl != null && imageUrl.isNotEmpty) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        _profileImageFile = file;
      }
    }
  }

  String _displayOrNotSet(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not set';
    return value.trim();
  }

  ImageProvider? _getProfileImage() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    if (_profileImageBytes != null) {
      return MemoryImage(_profileImageBytes!);
    }
    if (!kIsWeb &&
        _profileImageFile != null &&
        _profileImageFile!.existsSync()) {
      return FileImage(_profileImageFile!);
    }
    return null;
  }

  bool get _hasProfileImage => _getProfileImage() != null;

  Future<void> _goToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true) {
      _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color teal = Colors.teal;
    final imageProvider = _getProfileImage();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );
            }
          },
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.teal,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _showLogoutDialog(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
              animate: true,
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.indigo.shade900,
                              backgroundImage: imageProvider,
                              child: !_hasProfileImage
                                  ? Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              userBio,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _goToEditProfile,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text("Edit Profile"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        _buildSectionHeader("Account"),
                        const SizedBox(height: 8),
                        _buildCard(
                          children: [
                            _buildRow(
                              Icons.email_outlined,
                              "Email",
                              trailing: userEmail,
                              onTap: () {},
                            ),
                            _divider(),
                            _buildRow(
                              Icons.lock_outline,
                              "Change Password",
                              onTap: _showChangePasswordDialog,
                            ),
                            _divider(),
                            _buildRow(
                              Icons.phone_outlined,
                              "Phone Number",
                              trailing: userPhone.isNotEmpty
                                  ? userPhone
                                  : 'Not set',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader("Learning Profile"),
                        const SizedBox(height: 8),
                        _buildCard(
                          children: [
                            _buildRow(
                              Icons.cake_outlined,
                              "Date of Birth",
                              trailing: birthDate,
                              onTap: () {},
                            ),
                            _divider(),
                            _buildRow(
                              Icons.face_outlined,
                              "Gender",
                              trailing: gender,
                              onTap: () {},
                            ),
                            _divider(),
                            _buildRow(
                              Icons.menu_book_outlined,
                              "Learning Preferences",
                              trailing: interests,
                              onTap: () {},
                            ),
                            _divider(),
                            _buildRow(
                              Icons.flag_outlined,
                              "Goals / Reason",
                              trailing: reason,
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Change Password',
            style: GoogleFonts.poppins(color: Colors.teal),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.teal,
                    ),
                    onPressed: () => setDialogState(
                      () => obscureCurrent = !obscureCurrent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.teal,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.teal,
                    ),
                    onPressed: () => setDialogState(
                      () => obscureConfirm = !obscureConfirm,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(c),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: isSaving
                  ? null
                  : () async {
                      final current = currentController.text.trim();
                      final newPass = newController.text.trim();
                      final confirm = confirmController.text.trim();
                      if (current.isEmpty ||
                          newPass.isEmpty ||
                          confirm.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }
                      if (newPass != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      final result = await AuthService.changePassword(
                        email: userEmail,
                        currentPassword: current,
                        newPassword: newPass,
                      );
                      if (!context.mounted) return;
                      setDialogState(() => isSaving = false);
                      if (result['success'] == true) {
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message'] ?? 'Password changed',
                            ),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message'] ?? 'Could not change password',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Update',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?', style: GoogleFonts.poppins(color: Colors.red)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await AuthService.clearUserData();
              Navigator.pop(c);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade300, indent: 60);

  Widget _buildSectionHeader(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  Widget _buildCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _buildRow(
    IconData icon,
    String title, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title),
      trailing: trailing != null
          ? Text(
              trailing,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.end,
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
