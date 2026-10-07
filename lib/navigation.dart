import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'dashboard.dart';
import 'learning_hub.dart';
import 'save.dart';
import 'takepicture.dart';
import 'upload_content.dart';
import 'userprofile.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  final double fabSize = 62;

  @override
  void initState() {
    super.initState();
    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString('userEmail') ?? '').toLowerCase();
    if (email.isEmpty) return;
    await AuthService.getProfileFromServer(email);
    await BackendService.syncAllFromServer(emailOverride: email);
    if (mounted) _refreshPersistentTabs();
  }

  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  final GlobalKey<SavedScreenState> _savedKey = GlobalKey<SavedScreenState>();

  late final List<Widget> _screens = [
    DashboardScreen(key: _dashboardKey),
    const LearningHubScreen(),
    SavedScreen(key: _savedKey),
    const ProfileScreen(),
  ];

  // ─── Refresh tab content that may have changed elsewhere ────────
  // (e.g. new AI-generated summaries/flashcards/quizzes/audio notes)
  void _refreshPersistentTabs() {
    _dashboardKey.currentState?.refreshDashboard();
    _savedKey.currentState?.refreshSaved();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _isMenuOpen = false;
    });
    _refreshPersistentTabs();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  Future<void> _onTakePictureTap() async {
    setState(() => _isMenuOpen = false);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final extracted = await extractTextFromImageBytes(bytes, picked.name);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          uploadedFileName: picked.name,
          uploadedFileContent: extracted,
          initialAction: 'show_modal',
        ),
      ),
    ).then((_) => _refreshPersistentTabs());
  }

  void _onUploadFileTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadContentScreen()),
    ).then((_) => _refreshPersistentTabs());
    setState(() => _isMenuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Main Screen
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _screens[_selectedIndex],
            ),
          ),

          // ───────────── Floating ElevatedButton Menu ─────────────
          if (_isMenuOpen)
            Positioned(
              bottom: fabSize + 25,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isMenuOpen ? 1 : 0,
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Take Picture Button ─────────────────────
                      ElevatedButton.icon(
                        onPressed: _onTakePictureTap,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Take Picture"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ─── Upload File Button ──────────────────────
                      ElevatedButton.icon(
                        onPressed: _onUploadFileTap,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Upload File"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 2),
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ───────────── Custom Bottom Navigation Bar ─────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomBottomNavBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
              fabSize: fabSize,
            ),
          ),

          // ───────────── Floating Action Button ─────────────
          Positioned(
            bottom: 50,
            child: SizedBox(
              height: fabSize,
              width: fabSize,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _toggleMenu,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Icon(
                    _isMenuOpen ? Icons.close : Icons.add,
                    size: 30,
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────── Bottom Navigation Bar Classes ─────────────
class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final double fabSize;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.fabSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 80),
            painter: BNBCustomPainter(fabSize: fabSize),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home, 0),
                _buildNavItem(Icons.book_online_outlined, 1),
                const SizedBox(width: 48),
                _buildNavItem(Icons.bookmark, 2),
                _buildNavItem(Icons.person_outline, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: isSelected ? 3 : 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: isSelected
                    ? const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Icon(
                  icon,
                  size: isSelected ? 28 : 26,
                  color: isSelected
                      ? Colors.white
                      : const Color.fromARGB(255, 78, 73, 73),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────── Curved Bottom Painter ─────────────
class BNBCustomPainter extends CustomPainter {
  final double fabSize;
  BNBCustomPainter({required this.fabSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double fabRadius = fabSize / 2 + 8;
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(centerX - fabRadius - 10, 0);
    path.quadraticBezierTo(centerX - fabRadius, 0, centerX - fabRadius, 20);
    path.arcToPoint(
      Offset(centerX + fabRadius, 0),
      radius: Radius.circular(fabRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(centerX + fabRadius, 0, centerX + fabRadius + 10, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 8, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
