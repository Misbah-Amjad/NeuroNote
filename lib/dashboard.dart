import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:neuronote/audionoteplayer.dart';
import 'package:neuronote/flashcard_detail.dart';
import 'package:neuronote/premium_screen.dart';
import 'package:neuronote/quiz_detail.dart';
import 'package:neuronote/summarymindmap_detail.dart';
import 'package:neuronote/userprofile.dart';
import 'package:neuronote/weekly%20progress.dart';
import 'audionotescreen.dart';
import 'flashcard.dart';
import 'notification.dart';
import 'practice_quiz.dart';
import 'progress_service.dart';
import 'streak_screen.dart';
import 'summary and mindmap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'backend_service.dart';
import 'ai_chat.dart';
import 'save.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<double> weeklyData = [];
  double completionPercentage = 0;
  int currentStreak = 0;
  int totalActivities = 0;
  bool isLoading = true;
  Map<String, dynamic> apiData = {};

  // ─── Recommended Items ──────────────────────────────────────
  List<Map<String, dynamic>> recommendedItems = [];
  bool isLoadingRecommendations = true;
  int unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    LocalStorageService.storageVersion.addListener(_onStorageChanged);
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await _loadAllData();
    if (mounted) await _loadRecommendations();
  }

  void _onStorageChanged() {
    if (mounted) {
      _loadRecommendations();
      _loadUnreadNotificationCount();
    }
  }

  @override
  void dispose() {
    LocalStorageService.storageVersion.removeListener(_onStorageChanged);
    super.dispose();
  }

  // ─── Public refresh (called when this tab becomes active again,
  // e.g. after generating new AI content) ─────────────────────────
  Future<void> refreshDashboard() async {
    await _loadAllData();
    await _loadRecommendations();
    await _loadUnreadNotificationCount();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await NotificationService.getUnreadCount();
      if (mounted) {
        setState(() => unreadNotificationCount = count);
      }
    } catch (_) {}
  }

  Future<void> _checkMissedStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getString('last_active_date');

    if (lastActive != null) {
      final lastDate = DateTime.parse(lastActive);
      final now = DateTime.now();
      final difference = now.difference(lastDate).inDays;

      if (difference > 1) {
        final todayStr = '${now.day}/${now.month}/${now.year}';
        final lastMissedNotify = prefs.getString('last_missed_notify_date');

        if (lastMissedNotify != todayStr) {
          await NotificationService.trackMissedStreak();
          await prefs.setString('last_missed_notify_date', todayStr);
        }
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);

    try {
      // ── 1. Try backend stats first (user-specific, persistent) ──
      final backendStats = await BackendService.getStats();
      if (backendStats != null && backendStats.isNotEmpty) {
        // Sync backend progress into local storage
        await BackendService.syncProgressToLocal();

        final rawWeekly = backendStats['weekly_data'];
        if (rawWeekly is List && rawWeekly.isNotEmpty) {
          weeklyData = List<double>.from(
            rawWeekly.map((v) => (v as num).toDouble()),
          );
          final total = weeklyData.reduce((a, b) => a + b);
          completionPercentage = total / 7.0;
        }
        currentStreak = backendStats['current_streak'] as int? ?? 0;
        totalActivities =
            backendStats['total_activities'] as int? ?? 0;
      }

      // ── 2. Fallback / merge: read local ProgressService data ────
      final localData = await ProgressService.getWeeklyProgressList();
      if (localData.isNotEmpty &&
          (backendStats == null || backendStats.isEmpty)) {
        weeklyData = localData;
        final percentage = await ProgressService.getCompletionPercentage();
        completionPercentage = percentage;
        final streak = await ProgressService.getCurrentStreak();
        currentStreak = streak;
        final progress = await ProgressService.getWeeklyProgress();
        totalActivities = progress['total_activities'] ?? 0;
      } else if (localData.isNotEmpty) {
        // Always prefer higher streak from either source
        final localStreak = await ProgressService.getCurrentStreak();
        if (localStreak > currentStreak) currentStreak = localStreak;
        final localProgress = await ProgressService.getWeeklyProgress();
        final localTotal = localProgress['total_activities'] ?? 0;
        if (localTotal > totalActivities) totalActivities = localTotal;
      }

      // ── 3. Sync content from backend to local (restore history) ─
      await BackendService.syncContentToLocal();
      if (mounted) await _loadRecommendations();
    } catch (e) {
      print('Error loading data: $e');
      weeklyData = [0.4, 0.7, 0.2, 0.8, 0.5, 0.9, 0.6];
      completionPercentage = 0.6;
    } finally {
      await _loadUnreadNotificationCount();
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ─── Load Recommendations from Local Storage ────────────────
  Future<void> _loadRecommendations() async {
    setState(() => isLoadingRecommendations = true);

    try {
      final List<Map<String, dynamic>> items = [];

      // Collect all items, show only the single latest one
      final flashcards = await LocalStorageService.getFlashcards();
      for (var item in flashcards) {
        items.add({
          'id': item['id']?.toString() ?? '',
          'title': item['title'] ?? 'Flashcards',
          'subtitle': 'Study with flashcards • ${item['date'] ?? 'Recent'}',
          'type': 'flashcard',
          'icon': Icons.flash_on,
          'iconColor': Colors.deepPurple,
          'data': item,
          'action': 'flashcard',
        });
      }

      final quizzes = await LocalStorageService.getQuizzes();
      for (var item in quizzes) {
        items.add({
          'id': item['id']?.toString() ?? '',
          'title': item['title'] ?? 'Practice Quiz',
          'subtitle': 'Test your knowledge • ${item['date'] ?? 'Recent'}',
          'type': 'quiz',
          'icon': Icons.quiz,
          'iconColor': Colors.blueAccent,
          'data': item,
          'action': 'quiz',
        });
      }

      final summaries = await LocalStorageService.getSummaries();
      for (var item in summaries) {
        final isMindMap =
            item['action'] == 'mindmap' ||
            item['action'] == 'summary_mindmap';
        items.add({
          'id': item['id']?.toString() ?? '',
          'title': item['title'] ?? (isMindMap ? 'Mind Map' : 'Summary'),
          'subtitle':
              '${isMindMap ? 'Visualize' : 'Review'} your learning • ${item['date'] ?? 'Recent'}',
          'type': 'summary',
          'icon': isMindMap ? Icons.account_tree : Icons.description,
          'iconColor': isMindMap ? Colors.pink : Colors.teal,
          'data': item,
          'action': 'summary',
        });
      }

      final audioNotes = await LocalStorageService.getAudioNotes();
      for (var item in audioNotes) {
        items.add({
          'id': item['id']?.toString() ?? '',
          'title': item['title'] ?? 'Audio Note',
          'subtitle': 'Listen to your notes • ${item['date'] ?? 'Recent'}',
          'type': 'audio',
          'icon': Icons.audiotrack,
          'iconColor': Colors.orange,
          'data': item,
          'action': 'audio',
        });
      }

      // Show only the latest generated item
      items.sort((a, b) {
        final dateA = a['data']?['timestamp']?.toString() ?? '';
        final dateB = b['data']?['timestamp']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      setState(() {
        recommendedItems = items.take(1).toList();
        isLoadingRecommendations = false;
      });
    } catch (e) {
      setState(() => isLoadingRecommendations = false);
    }
  }

  // ─── Navigate to content detail ─────────────────────────────
  void _openRecommendedItem(Map<String, dynamic> item) {
    final type = item['type'] ?? '';
    final data = item['data'] ?? {};
    final title = item['title'] ?? 'Content';

    switch (type) {
      case 'flashcard':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FlashcardDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'quiz':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                QuizDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'summary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SummaryMindMapDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'audio':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AudioNotePlayerScreen(
              title: title,
              subtitle: data['preview']?.toString() ?? 'Audio note',
              scriptContent: data['content']?.toString() ?? '',
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: $title'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.teal,
          ),
        );
    }
  }

  // ─── Navigate to AI Chat with a specific action ─────────────
  void _navigateToAIWithAction(String action, {String? content}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AIChatScreen(initialAction: action, initialContent: content ?? ''),
      ),
    ).then((_) {
      if (mounted) {
        _loadAllData();
        _loadRecommendations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Avatar and Notification Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          foregroundColor: Colors.teal,
                          backgroundColor: Color(0xFFE0E6EB),
                          radius: 20,
                          child: Icon(Icons.person, color: Colors.teal),
                        ),
                      ),
                      Text(
                        'Dashboard',
                        style: GoogleFonts.poppins(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      IconButton(
                        color: Colors.grey,
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationScreen(),
                            ),
                          );
                          if (mounted) await _loadUnreadNotificationCount();
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none),
                            if (unreadNotificationCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadNotificationCount > 99
                                        ? '99+'
                                        : '$unreadNotificationCount',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Streak Card
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StreakScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🔥 $currentStreak Day Streak',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                                Text(
                                  totalActivities > 0
                                      ? '$totalActivities activities this week'
                                      : 'Start learning to build your streak!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weekly Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Weekly Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WeeklyProgressScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const WeeklyProgressScreen(),
                                  ),
                                );
                              },
                              child: BarChartPlaceholder(
                                data: weeklyData,
                                labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const WeeklyProgressScreen(),
                                  ),
                                );
                              },
                              child: CompletionRing(
                                percentage: completionPercentage.clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─── 4 Main Action Cards ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FlashcardsScreen(),
                              ),
                            );
                          },
                          child: const ActionButton(
                            icon: Icons.flash_on,
                            label: 'Flashcards',
                            subtitle: 'Study with cards',
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PracticeQuizScreen(),
                              ),
                            );
                          },
                          child: const ActionButton(
                            icon: Icons.quiz,
                            label: 'Practice Quizzes',
                            subtitle: 'Test your knowledge',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SummaryMindMapScreen(),
                              ),
                            );
                          },
                          child: const ActionButton(
                            icon: Icons.description,
                            label: 'Summaries & Mind Maps',
                            subtitle: 'Visualize your learning',
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AudioNoteScreen(),
                              ),
                            );
                          },
                          child: const ActionButton(
                            icon: Icons.audiotrack,
                            label: 'Generate Audio Notes',
                            subtitle: 'Listen to your notes',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ─── RECOMMENDED FOR YOU SECTION ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended for You',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      if (recommendedItems.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SavedScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              color: Colors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ─── Recommended Items Grid ──────────────────────
                  if (isLoadingRecommendations)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    )
                  else if (recommendedItems.isEmpty)
                    _buildEmptyRecommendations()
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: recommendedItems.length,
                      itemBuilder: (context, index) {
                        final item = recommendedItems[index];
                        return _buildRecommendedCard(item);
                      },
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.teal, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock, color: Colors.teal, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          "Want more Features?",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Upgrade to Premium to unlock full access to advanced options",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PremiumScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.upgrade),
                          label: const Text("Upgrade to Premium"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
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

  // ─── Empty Recommendations Widget ───────────────────────────
  Widget _buildEmptyRecommendations() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No recommendations yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate content from AI Chat to get personalized recommendations!',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              ).then((_) {
                if (mounted) {
                  _loadAllData();
                  _loadRecommendations();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Go to AI Chat',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recommended Card Widget ────────────────────────────────
  Widget _buildRecommendedCard(Map<String, dynamic> item) {
    final icon = item['icon'] as IconData;
    final iconColor = item['iconColor'] as Color;
    final title = item['title'] ?? 'Content';
    final subtitle = item['subtitle'] ?? '';

    return GestureDetector(
      onTap: () => _openRecommendedItem(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getTypeLabel(item['type'] ?? ''),
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'flashcard':
        return '📚 Flashcards';
      case 'quiz':
        return '📝 Quiz';
      case 'summary':
        return '📄 Summary';
      case 'audio':
        return '🎧 Audio';
      default:
        return '📖 Content';
    }
  }
}

// ─── ActionButton ─────────────────────────────────────────────

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.4),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
    );
  }
}

// ─── BarChartPlaceholder ─────────────────────────────────────

class BarChartPlaceholder extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const BarChartPlaceholder({
    super.key,
    required this.data,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final maxHeight = 70.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(data.length, (index) {
        final height = maxValue > 0 ? (data[index] / maxValue) * maxHeight : 0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height + 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.teal, Colors.teal.shade200],
                    ),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── CompletionRing ──────────────────────────────────────────

class CompletionRing extends StatelessWidget {
  final double percentage;

  const CompletionRing({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final double validPercentage = percentage.clamp(0.0, 1.0).toDouble();

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: validPercentage,
            strokeWidth: 8,
            backgroundColor: const Color(0xFFE0E6EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              validPercentage > 0.7 ? Colors.teal : Colors.orange,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(validPercentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: validPercentage > 0.7 ? Colors.teal : Colors.orange,
              ),
            ),
            const Text(
              'Complete',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
