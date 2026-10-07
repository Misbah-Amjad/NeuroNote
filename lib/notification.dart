import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'navigation.dart';

// ─── Notification Model ──────────────────────────────────────
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String
  type; // 'streak', 'missed_streak', 'flashcard', 'quiz', 'summary', 'audio', 'mindmap'
  final DateTime timestamp;
  final String date; // 'DD/MM/YYYY' format
  final String day; // 'Monday', 'Tuesday', etc.
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.date,
    required this.day,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'date': date,
    'day': day,
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'],
        title: json['title'],
        message: json['message'],
        type: json['type'],
        timestamp: DateTime.parse(json['timestamp']),
        date: json['date'],
        day: json['day'],
        isRead: json['isRead'] ?? false,
      );
}

// ─── Notification Service ────────────────────────────────────
class NotificationService {
  static const String _notificationsKey = 'neuronote_notifications';

  static const Map<String, String> _dayNames = {
    '1': 'Monday',
    '2': 'Tuesday',
    '3': 'Wednesday',
    '4': 'Thursday',
    '5': 'Friday',
    '6': 'Saturday',
    '7': 'Sunday',
  };

  static String _getDayName(DateTime date) {
    return _dayNames[date.weekday.toString()] ?? 'Unknown';
  }

  static String _getDateString(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Get all notifications
  static Future<List<NotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await AuthService.scopedKey(_notificationsKey);
    final String? data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.map((item) => NotificationItem.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save notifications
  static Future<void> _saveNotifications(
    List<NotificationItem> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await AuthService.scopedKey(_notificationsKey);
    final String data = jsonEncode(
      notifications.map((n) => n.toJson()).toList(),
    );
    await prefs.setString(key, data);
  }

  // Add a notification
  static Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    bool allowMultiplePerDay = false,
  }) async {
    final notifications = await getNotifications();
    final now = DateTime.now();

    final todayDate = _getDateString(now);
    if (!allowMultiplePerDay) {
      final existingToday = notifications.any(
        (n) => n.type == type && n.date == todayDate,
      );
      if (existingToday) {
        return;
      }
    }

    final notification = NotificationItem(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: now,
      date: todayDate,
      day: _getDayName(now),
    );

    notifications.insert(0, notification);
    await _saveNotifications(notifications);
  }

  // Mark notification as read
  static Future<void> markAsRead(String id) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updated = notifications[index];
      notifications[index] = NotificationItem(
        id: updated.id,
        title: updated.title,
        message: updated.message,
        type: updated.type,
        timestamp: updated.timestamp,
        date: updated.date,
        day: updated.day,
        isRead: true,
      );
      await _saveNotifications(notifications);
    }
  }

  // Mark all as read
  static Future<void> markAllAsRead() async {
    final notifications = await getNotifications();
    final updated = notifications
        .map(
          (n) => NotificationItem(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            timestamp: n.timestamp,
            date: n.date,
            day: n.day,
            isRead: true,
          ),
        )
        .toList();
    await _saveNotifications(updated);
  }

  // Delete notification
  static Future<void> deleteNotification(String id) async {
    final notifications = await getNotifications();
    final updated = notifications.where((n) => n.id != id).toList();
    await _saveNotifications(updated);
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await AuthService.scopedKey(_notificationsKey));
  }

  // Get unread count
  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // ─── Activity Trackers ──────────────────────────────────────

  static Future<void> trackStreakUpdated(int streak) async {
    final now = DateTime.now();
    final dateStr = _getDateString(now);
    final dayName = _getDayName(now);

    await addNotification(
      title: '🔥 Streak Updated',
      message: 'You reached $streak-day streak on $dayName, $dateStr',
      type: 'streak',
    );
  }

  static Future<void> trackMissedStreak() async {
    final now = DateTime.now();
    final dateStr = _getDateString(now);
    final dayName = _getDayName(now);

    await addNotification(
      title: '⚠️ Streak Missed',
      message: 'You missed your streak on $dayName, $dateStr',
      type: 'missed_streak',
    );
  }

  static Future<void> trackFlashcardGenerated() async {
    await addNotification(
      title: '📚 Flashcards Generated',
      message: 'New flashcards were generated from your content',
      type: 'flashcard',
      allowMultiplePerDay: true,
    );
  }

  static Future<void> trackQuizGenerated() async {
    await addNotification(
      title: '📝 Practice Quiz Generated',
      message: 'A new practice quiz was generated from your content',
      type: 'quiz',
      allowMultiplePerDay: true,
    );
  }

  static Future<void> trackSummaryGenerated() async {
    await addNotification(
      title: '📄 Summary Generated',
      message: 'A new summary was generated from your content',
      type: 'summary',
      allowMultiplePerDay: true,
    );
  }

  static Future<void> trackMindMapGenerated() async {
    await addNotification(
      title: '🗺️ Mind Map Generated',
      message: 'A new mind map was generated from your content',
      type: 'mindmap',
      allowMultiplePerDay: true,
    );
  }

  static Future<void> trackAudioNoteGenerated() async {
    await addNotification(
      title: '🎧 Audio Note Generated',
      message: 'A new audio note was generated from your content',
      type: 'audio',
      allowMultiplePerDay: true,
    );
  }
}

// ─── Notification Screen ─────────────────────────────────────

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> notifications = [];
  bool isLoading = true;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    try {
      final data = await NotificationService.getNotifications();
      final unread = await NotificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          notifications = data;
          unreadCount = unread;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear All Notifications?',
          style: GoogleFonts.poppins(color: Colors.red),
        ),
        content: Text(
          'All notifications will be permanently deleted.',
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
              await NotificationService.clearAllNotifications();
              if (mounted) {
                Navigator.pop(c);
                await _loadNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All notifications cleared'),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationService.deleteNotification(id);
    await _loadNotifications();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          },
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.teal),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.9,
              child: Lottie.asset(
                'assets/animations/Sparkles Animation.json',
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal))
          else if (notifications.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Notifications Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your activity notifications will appear here',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainNavigation(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Go to Dashboard',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = !notification.isRead;

                // Get emoji based on type
                String emoji = '🔔';
                Color color = Colors.teal;
                switch (notification.type) {
                  case 'streak':
                    emoji = '🔥';
                    color = Colors.orange;
                    break;
                  case 'missed_streak':
                    emoji = '⚠️';
                    color = Colors.red;
                    break;
                  case 'flashcard':
                    emoji = '📚';
                    color = Colors.deepPurple;
                    break;
                  case 'quiz':
                    emoji = '📝';
                    color = Colors.blueAccent;
                    break;
                  case 'summary':
                    emoji = '📄';
                    color = Colors.teal;
                    break;
                  case 'mindmap':
                    emoji = '🗺️';
                    color = Colors.pink;
                    break;
                  case 'audio':
                    emoji = '🎧';
                    color = Colors.orange;
                    break;
                  default:
                    emoji = '🔔';
                    color = Colors.teal;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? Colors.teal.shade50.withOpacity(0.9)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isUnread
                          ? Colors.teal.shade200
                          : Colors.grey.shade200,
                      width: isUnread ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      notification.title,
                      style: GoogleFonts.poppins(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                        color: isUnread ? Colors.black87 : Colors.grey.shade700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.message,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getDateLabel(notification.timestamp),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              notification.day,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              notification.date,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () => _deleteNotification(notification.id),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (isUnread) {
                        await NotificationService.markAsRead(notification.id);
                        await _loadNotifications();
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
