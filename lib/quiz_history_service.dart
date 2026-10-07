import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class QuizHistoryService {
  static const String _quizHistoryKey = 'neuronote_quiz_history';
  static const String _quizStatsKey = 'neuronote_quiz_stats';

  // ─── Save Quiz Attempt ──────────────────────────────────────

  static Future<void> saveQuizAttempt({
    required String quizId,
    required String quizTitle,
    required int totalQuestions,
    required int correctAnswers,
    required int wrongAnswers,
    required List<Map<String, dynamic>> questionResults,
    double? timeTaken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getQuizHistory();

      final entry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'quizId': quizId,
        'quizTitle': quizTitle,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'score': totalQuestions > 0
            ? (correctAnswers / totalQuestions * 100).round()
            : 0,
        'questionResults': questionResults,
        'timeTaken': timeTaken ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };

      history.insert(0, entry);
      await prefs.setString(_quizHistoryKey, jsonEncode(history));

      // Update stats
      await _updateStats(entry);

      return;
    } catch (e) {
      print('Error saving quiz history: $e');
    }
  }

  // ─── Get All Quiz History ────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getQuizHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_quizHistoryKey);
      if (data != null && data.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
      return [];
    } catch (e) {
      print('Error loading quiz history: $e');
      return [];
    }
  }

  // ─── Get Quiz History by Quiz ID ─────────────────────────────

  static Future<List<Map<String, dynamic>>> getQuizHistoryByQuizId(
    String quizId,
  ) async {
    final history = await getQuizHistory();
    return history.where((entry) => entry['quizId'] == quizId).toList();
  }

  // ─── Get Recent Quiz Attempts ────────────────────────────────

  static Future<List<Map<String, dynamic>>> getRecentQuizAttempts({
    int limit = 10,
  }) async {
    final history = await getQuizHistory();
    if (history.length > limit) {
      return history.sublist(0, limit);
    }
    return history;
  }

  // ─── Get Quiz Stats ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getQuizStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_quizStatsKey);
      if (data != null && data.isNotEmpty) {
        return jsonDecode(data);
      }
      return _getDefaultStats();
    } catch (e) {
      return _getDefaultStats();
    }
  }

  static Map<String, dynamic> _getDefaultStats() {
    return {
      'totalQuizzesTaken': 0,
      'totalQuestionsAnswered': 0,
      'totalCorrectAnswers': 0,
      'totalWrongAnswers': 0,
      'averageScore': 0,
      'bestScore': 0,
      'lastQuizDate': null,
      'quizzesByDay': {},
      'streak': 0,
    };
  }

  // ─── Update Stats ─────────────────────────────────────────────

  static Future<void> _updateStats(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> stats = await getQuizStats();

      // Update counts with proper type casting
      stats['totalQuizzesTaken'] =
          (stats['totalQuizzesTaken'] as int? ?? 0) + 1;
      stats['totalQuestionsAnswered'] =
          (stats['totalQuestionsAnswered'] as int? ?? 0) +
          (entry['totalQuestions'] as int? ?? 0);
      stats['totalCorrectAnswers'] =
          (stats['totalCorrectAnswers'] as int? ?? 0) +
          (entry['correctAnswers'] as int? ?? 0);
      stats['totalWrongAnswers'] =
          (stats['totalWrongAnswers'] as int? ?? 0) +
          (entry['wrongAnswers'] as int? ?? 0);

      // Update average score
      final totalCorrect = stats['totalCorrectAnswers'] as int? ?? 0;
      final totalAnswered = stats['totalQuestionsAnswered'] as int? ?? 0;
      stats['averageScore'] = totalAnswered > 0
          ? (totalCorrect / totalAnswered * 100).round()
          : 0;

      // Update best score
      final currentScore = entry['score'] as int? ?? 0;
      final bestScore = stats['bestScore'] as int? ?? 0;
      if (currentScore > bestScore) {
        stats['bestScore'] = currentScore;
      }

      // Update last quiz date
      stats['lastQuizDate'] = entry['date'];

      // Update daily quiz count
      final date =
          entry['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      Map<String, dynamic> quizzesByDay = Map<String, dynamic>.from(
        stats['quizzesByDay'] ?? {},
      );
      quizzesByDay[date] = (quizzesByDay[date] as int? ?? 0) + 1;
      stats['quizzesByDay'] = quizzesByDay;

      // Update streak
      stats['streak'] = await _calculateStreak(quizzesByDay);

      await prefs.setString(_quizStatsKey, jsonEncode(stats));
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  // ─── Calculate Streak ────────────────────────────────────────

  static Future<int> _calculateStreak(Map<String, dynamic> quizzesByDay) async {
    if (quizzesByDay.isEmpty) return 0;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    // Check if quiz was taken today or yesterday
    if (!quizzesByDay.containsKey(today) &&
        !quizzesByDay.containsKey(yesterday)) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = DateTime.now();

    // Start from today and go backwards
    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
      if (quizzesByDay.containsKey(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ─── Clear All History ───────────────────────────────────────

  static Future<void> clearAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_quizHistoryKey);
      await prefs.remove(_quizStatsKey);
    } catch (e) {
      print('Error clearing quiz history: $e');
    }
  }

  // ─── Delete Single History Entry ────────────────────────────

  static Future<void> deleteHistoryEntry(String entryId) async {
    try {
      final history = await getQuizHistory();
      final updated = history.where((entry) => entry['id'] != entryId).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizHistoryKey, jsonEncode(updated));

      // Recalculate stats
      await _recalculateStats(updated);
    } catch (e) {
      print('Error deleting history entry: $e');
    }
  }

  // ─── Recalculate Stats from History ─────────────────────────

  static Future<void> _recalculateStats(
    List<Map<String, dynamic>> history,
  ) async {
    try {
      if (history.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_quizStatsKey, jsonEncode(_getDefaultStats()));
        return;
      }

      int totalQuizzes = history.length;
      int totalQuestions = 0;
      int totalCorrect = 0;
      int totalWrong = 0;
      int bestScore = 0;
      Map<String, dynamic> quizzesByDay = {};

      for (var entry in history) {
        totalQuestions += entry['totalQuestions'] as int? ?? 0;
        totalCorrect += entry['correctAnswers'] as int? ?? 0;
        totalWrong += entry['wrongAnswers'] as int? ?? 0;

        final score = entry['score'] as int? ?? 0;
        if (score > bestScore) bestScore = score;

        final date =
            entry['date'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.parse(entry['timestamp']));
        quizzesByDay[date] = (quizzesByDay[date] as int? ?? 0) + 1;
      }

      final stats = {
        'totalQuizzesTaken': totalQuizzes,
        'totalQuestionsAnswered': totalQuestions,
        'totalCorrectAnswers': totalCorrect,
        'totalWrongAnswers': totalWrong,
        'averageScore': totalQuestions > 0
            ? (totalCorrect / totalQuestions * 100).round()
            : 0,
        'bestScore': bestScore,
        'lastQuizDate': history.isNotEmpty ? history.first['date'] : null,
        'quizzesByDay': quizzesByDay,
        'streak': await _calculateStreak(quizzesByDay),
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizStatsKey, jsonEncode(stats));
    } catch (e) {
      print('Error recalculating stats: $e');
    }
  }

  // ─── Get Quiz Performance by Day ────────────────────────────

  static Future<Map<String, int>> getDailyQuizCount({int days = 30}) async {
    final history = await getQuizHistory();
    final result = <String, int>{};

    for (int i = 0; i < days; i++) {
      final date = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().subtract(Duration(days: i)));
      result[date] = 0;
    }

    for (var entry in history) {
      final date =
          entry['date'] ??
          DateFormat('yyyy-MM-dd').format(DateTime.parse(entry['timestamp']));
      if (result.containsKey(date)) {
        result[date] = (result[date] ?? 0) + 1;
      }
    }

    return result;
  }

  // ─── Get Quiz Performance by Quiz ────────────────────────────

  static Future<Map<String, dynamic>> getQuizPerformance() async {
    final history = await getQuizHistory();
    final performance = <String, Map<String, dynamic>>{};

    for (var entry in history) {
      final quizId = entry['quizId'] ?? 'unknown';
      if (!performance.containsKey(quizId)) {
        performance[quizId] = {
          'title': entry['quizTitle'] ?? 'Unknown Quiz',
          'attempts': 0,
          'totalCorrect': 0,
          'totalQuestions': 0,
          'scores': [],
          'bestScore': 0,
          'latestScore': 0,
        };
      }

      final stats = performance[quizId]!;
      stats['attempts'] = (stats['attempts'] as int? ?? 0) + 1;
      stats['totalCorrect'] =
          (stats['totalCorrect'] as int? ?? 0) +
          (entry['correctAnswers'] as int? ?? 0);
      stats['totalQuestions'] =
          (stats['totalQuestions'] as int? ?? 0) +
          (entry['totalQuestions'] as int? ?? 0);
      stats['scores'] = [...stats['scores'] as List, entry['score'] ?? 0];

      final score = entry['score'] as int? ?? 0;
      if (score > (stats['bestScore'] as int? ?? 0)) {
        stats['bestScore'] = score;
      }
      stats['latestScore'] = score;
    }

    // Calculate averages
    for (var key in performance.keys) {
      final stats = performance[key]!;
      final totalQuestions = stats['totalQuestions'] as int? ?? 0;
      stats['averageScore'] = totalQuestions > 0
          ? ((stats['totalCorrect'] as int? ?? 0) / totalQuestions * 100)
                .round()
          : 0;
    }

    return performance;
  }
}
