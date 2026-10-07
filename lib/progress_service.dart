import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'backend_service.dart';

class ProgressService {
  static const String _progressKeyBase = 'weekly_progress_data';

  static Future<String> _progressKey() =>
      AuthService.scopedKey(_progressKeyBase);
  static Future<String> _streakKey(String name) => AuthService.scopedKey(name);

  // Save weekly progress data
  static Future<void> saveWeeklyProgress(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _progressKey(), jsonEncode(data));
  }

  // Get weekly progress data
  static Future<Map<String, dynamic>> getWeeklyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await _progressKey());
    if (data != null) {
      return jsonDecode(data);
    }
    return _getDefaultProgress();
  }

  // Get default progress data
  static Map<String, dynamic> _getDefaultProgress() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    Map<String, double> dailyData = {};
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailyData[key] = 0.0;
    }

    return {
      'week_start': DateFormat('yyyy-MM-dd').format(weekStart),
      'daily_data': dailyData,
      'total_activities': 0,
      'completed_tasks': 0,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  // Update progress for a specific day
  static Future<void> updateProgress(String date, double value) async {
    final progress = await getWeeklyProgress();
    final dailyData = Map<String, double>.from(progress['daily_data']);
    dailyData[date] = (dailyData[date] ?? 0) + value;

    progress['daily_data'] = dailyData;
    progress['total_activities'] = dailyData.values
        .reduce((a, b) => a + b)
        .toInt();
    progress['last_updated'] = DateTime.now().toIso8601String();

    await saveWeeklyProgress(progress);
  }

  // Get today's progress
  static Future<double> getTodayProgress() async {
    final progress = await getWeeklyProgress();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return (progress['daily_data'][today] ?? 0).toDouble();
  }

  // Get current streak
  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _streakKey('current_streak')) ?? 0;
  }

  // Update streak
  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastActiveKey = await _streakKey('last_active_date');
    final currentStreakKey = await _streakKey('current_streak');
    final lastActive = prefs.getString(lastActiveKey);

    if (lastActive == null) {
      await prefs.setInt(currentStreakKey, 1);
      await prefs.setString(lastActiveKey, today);
      return;
    }

    final lastDate = DateTime.parse(lastActive);
    final now = DateTime.now();
    final difference = now.difference(lastDate).inDays;

    if (difference == 0) {
      return;
    } else if (difference == 1) {
      final currentStreak = prefs.getInt(currentStreakKey) ?? 0;
      await prefs.setInt(currentStreakKey, currentStreak + 1);
      await prefs.setString(lastActiveKey, today);
    } else {
      await prefs.setInt(currentStreakKey, 1);
      await prefs.setString(lastActiveKey, today);
    }
  }

  // Get best streak
  static Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _streakKey('best_streak')) ?? 0;
  }

  // Update best streak
  static Future<void> updateBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStreakKey = await _streakKey('current_streak');
    final bestStreakKey = await _streakKey('best_streak');
    final currentStreak = prefs.getInt(currentStreakKey) ?? 0;
    final bestStreak = prefs.getInt(bestStreakKey) ?? 0;

    if (currentStreak > bestStreak) {
      await prefs.setInt(bestStreakKey, currentStreak);
    }
  }

  // Get weekly progress as list for chart
  static Future<List<double>> getWeeklyProgressList() async {
    final progress = await getWeeklyProgress();
    final dailyData = Map<String, double>.from(progress['daily_data']);

    // Get days in order (Monday to Sunday)
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    List<double> data = [];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      data.add(dailyData[key] ?? 0.0);
    }
    return data;
  }

  // Get completion percentage for the week
  static Future<double> getCompletionPercentage() async {
    final data = await getWeeklyProgressList();
    final total = data.reduce((a, b) => a + b);
    final maxPossible = 7.0; // Max 1.0 per day
    return total / maxPossible;
  }

  // Record an activity (flashcard, quiz, etc.)
  static Future<void> recordActivity(String type) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Different weights for different activities
    double weight = 0.0;
    switch (type) {
      case 'flashcard':
        weight = 0.2;
        break;
      case 'quiz':
        weight = 0.3;
        break;
      case 'summary':
        weight = 0.25;
        break;
      case 'audio_note':
        weight = 0.15;
        break;
      case 'mindmap':
        weight = 0.25;
        break;
      default:
        weight = 0.1;
    }

    await updateProgress(today, weight);
    await updateStreak();
    await updateBestStreak();
    // Sync progress to backend (fire-and-forget)
    BackendService.saveProgress();
  }
}
