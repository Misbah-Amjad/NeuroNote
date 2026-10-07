import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://libaasehamza.store/projects/data_n.php';

  // Local storage keys
  static const String _cacheKey = 'neuronote_api_cache';
  static const String _lastFetchKey = 'neuronote_last_fetch';

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Fetch all data with caching
  static Future<Map<String, dynamic>> fetchAllData({
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await _getCachedData();
        if (cached != null) {
          developer.log('Using cached data');
          return cached;
        }
      }

      final url = Uri.parse('$baseUrl?api=get_all');
      developer.log('Fetching data from: $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      developer.log('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          developer.log('Data fetched successfully');
          // Cache the data
          await _cacheData(data['data']);
          return data['data'];
        }
      }

      // If API fails, try cache again or use fallback
      final cached = await _getCachedData();
      if (cached != null) {
        return cached;
      }
      return _getFallbackData();
    } catch (e) {
      developer.log('Error fetching data: $e');
      // Try cache on error
      final cached = await _getCachedData();
      if (cached != null) {
        return cached;
      }
      return _getFallbackData();
    }
  }

  // Cache methods
  static Future<void> _cacheData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
      developer.log('Data cached successfully');
    } catch (e) {
      developer.log('Error caching data: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_cacheKey);
      final String? lastFetch = prefs.getString(_lastFetchKey);

      if (data == null) return null;

      // Check if cache is still valid
      if (lastFetch != null) {
        final fetchTime = DateTime.parse(lastFetch);
        if (DateTime.now().difference(fetchTime) > _cacheDuration) {
          developer.log('Cache expired');
          return null;
        }
      }

      return jsonDecode(data);
    } catch (e) {
      developer.log('Error reading cache: $e');
      return null;
    }
  }

  // Fetch flashcards
  static Future<List<dynamic>> fetchFlashcards({
    bool forceRefresh = false,
  }) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['flashcards'] ?? _getFallbackFlashcards();
    } catch (e) {
      return _getFallbackFlashcards();
    }
  }

  // Fetch quizzes
  static Future<List<dynamic>> fetchQuizzes({bool forceRefresh = false}) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['quizzes'] ?? _getFallbackQuizzes();
    } catch (e) {
      return _getFallbackQuizzes();
    }
  }

  // Fetch summaries
  static Future<List<dynamic>> fetchSummaries({
    bool forceRefresh = false,
  }) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['summaries'] ?? _getFallbackSummaries();
    } catch (e) {
      return _getFallbackSummaries();
    }
  }

  // Fetch audio notes
  static Future<List<dynamic>> fetchAudioNotes({
    bool forceRefresh = false,
  }) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['audio_notes'] ?? _getFallbackAudioNotes();
    } catch (e) {
      return _getFallbackAudioNotes();
    }
  }

  // Fetch learning hub items
  static Future<List<dynamic>> fetchLearningHubItems({
    bool forceRefresh = false,
  }) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['learning_hub'] ?? _getFallbackLearningHubItems();
    } catch (e) {
      return _getFallbackLearningHubItems();
    }
  }

  // Fetch stats
  static Future<Map<String, dynamic>> fetchStats({
    bool forceRefresh = false,
  }) async {
    try {
      final allData = await fetchAllData(forceRefresh: forceRefresh);
      return allData['stats'] ?? _getFallbackStats();
    } catch (e) {
      return _getFallbackStats();
    }
  }

  // ─── Fallback Data ──────────────────────────────────────────

  static Map<String, dynamic> _getFallbackData() {
    return {
      'flashcards': _getFallbackFlashcards(),
      'quizzes': _getFallbackQuizzes(),
      'summaries': _getFallbackSummaries(),
      'audio_notes': _getFallbackAudioNotes(),
      'learning_hub': _getFallbackLearningHubItems(),
      'stats': _getFallbackStats(),
    };
  }

  static List<dynamic> _getFallbackFlashcards() {
    return [
      {
        'id': 1,
        'title': 'Biology - Cell Structure',
        'description': 'Organelles and their functions',
        'total_cards': 15,
        'category': 'Biology',
        'cards': [
          {
            'question': 'What is the powerhouse of the cell?',
            'answer': 'Mitochondria',
          },
          {
            'question': 'What organelle contains digestive enzymes?',
            'answer': 'Lysosomes',
          },
          {
            'question': 'What is the function of the nucleus?',
            'answer': 'Control center containing DNA',
          },
          {
            'question': 'What is the endoplasmic reticulum?',
            'answer': 'Network of membranes for protein synthesis',
          },
          {
            'question': 'What does the Golgi apparatus do?',
            'answer': 'Modifies, sorts, and packages proteins',
          },
        ],
      },
      {
        'id': 2,
        'title': 'Physics - Laws of Motion',
        'description': "Newton's three laws explained",
        'total_cards': 12,
        'category': 'Physics',
        'cards': [
          {
            'question': "What is Newton's First Law?",
            'answer':
                'An object at rest stays at rest unless acted upon by an external force',
          },
          {
            'question': "What is Newton's Second Law?",
            'answer': 'F = ma - Force equals mass times acceleration',
          },
          {
            'question': "What is Newton's Third Law?",
            'answer':
                'For every action, there is an equal and opposite reaction',
          },
        ],
      },
      {
        'id': 3,
        'title': 'Chemistry - Periodic Table',
        'description': 'Elements and their properties',
        'total_cards': 20,
        'category': 'Chemistry',
        'cards': [
          {'question': 'What is the atomic number of Carbon?', 'answer': '6'},
          {'question': 'What is the symbol for Gold?', 'answer': 'Au'},
          {
            'question': 'What is the most abundant element in the universe?',
            'answer': 'Hydrogen',
          },
        ],
      },
    ];
  }

  static List<dynamic> _getFallbackQuizzes() {
    return [
      {
        'id': 1,
        'title': 'Biology Quiz - Cell Division',
        'questions': 10,
        'difficulty': 'Medium',
        'quiz_data': [
          {
            'question': 'What is mitosis?',
            'options': [
              'Cell division for growth',
              'Cell division for reproduction',
              'Cell death',
              'Cell fusion',
            ],
            'correct': 'Cell division for growth',
          },
          {
            'question': 'How many chromosomes do humans have?',
            'options': ['23', '46', '44', '48'],
            'correct': '46',
          },
        ],
      },
      {
        'id': 2,
        'title': 'Physics Quiz - Optics',
        'questions': 8,
        'difficulty': 'Hard',
        'quiz_data': [
          {
            'question': 'What is the speed of light?',
            'options': ['3×10⁸ m/s', '3×10⁶ m/s', '3×10¹⁰ m/s', '3×10⁴ m/s'],
            'correct': '3×10⁸ m/s',
          },
        ],
      },
      {
        'id': 3,
        'title': 'Chemistry Quiz - Chemical Reactions',
        'questions': 12,
        'difficulty': 'Easy',
        'quiz_data': [
          {
            'question': 'What is the chemical formula for water?',
            'options': ['H2O', 'CO2', 'NaCl', 'HCl'],
            'correct': 'H2O',
          },
        ],
      },
    ];
  }

  static List<dynamic> _getFallbackSummaries() {
    return [
      {
        'id': 1,
        'title': 'Biology - Photosynthesis Summary',
        'content':
            'Photosynthesis is the process by which plants convert sunlight into energy, producing glucose and oxygen. This occurs in chloroplasts using chlorophyll.',
        'type': 'summary',
      },
      {
        'id': 2,
        'title': 'Physics - Thermodynamics Mind Map',
        'content':
            'The Laws of Thermodynamics describe energy transfer, entropy, and the behavior of heat in systems.',
        'type': 'mindmap',
      },
      {
        'id': 3,
        'title': 'History - Renaissance Summary',
        'content':
            'The Renaissance period (14th-17th century) marked a cultural rebirth in Europe, focusing on art, science, and humanism.',
        'type': 'summary',
      },
    ];
  }

  static List<dynamic> _getFallbackAudioNotes() {
    return [
      {
        'id': 1,
        'title': 'Biology - Human Digestive System',
        'description': '5-minute audio explaining digestion process',
        'duration': '5:12',
      },
      {
        'id': 2,
        'title': 'Physics - Laws of Motion',
        'description': "Newton's laws explained with examples",
        'duration': '4:45',
      },
      {
        'id': 3,
        'title': 'Chemistry - Acids and Bases',
        'description': 'Learn about pH and reactions',
        'duration': '3:58',
      },
    ];
  }

  static List<dynamic> _getFallbackLearningHubItems() {
    return [
      {
        'id': 1,
        'title': 'Human Brain Structure',
        'description': 'Neuroscience fundamentals',
        'category': 'Science',
      },
      {
        'id': 2,
        'title': 'Cognitive Psychology',
        'description': 'How the mind processes information',
        'category': 'Psychology',
      },
      {
        'id': 3,
        'title': 'AI in Education',
        'description': 'How AI is transforming learning',
        'category': 'Technology',
      },
      {
        'id': 4,
        'title': 'Biology - Cell Division',
        'description': 'Understanding mitosis and meiosis',
        'category': 'Biology',
      },
      {
        'id': 5,
        'title': 'Physics - Quantum Basics',
        'description': 'Introduction to quantum theory',
        'category': 'Physics',
      },
      {
        'id': 6,
        'title': 'Chemistry - Periodic Table',
        'description': 'Trends and elements explained',
        'category': 'Chemistry',
      },
    ];
  }

  static Map<String, dynamic> _getFallbackStats() {
    return {
      'total_users': 3,
      'total_flashcards': 3,
      'total_quizzes': 3,
      'total_activities': 95,
      'avg_streak': 8,
      'weekly_data': [0.4, 0.7, 0.2, 0.8, 0.5, 0.9, 0.6],
      'last_updated': DateTime.now().toString(),
    };
  }
  // ─── Quiz Result Management ──────────────────────────────────

  // Save quiz result to server
  static Future<Map<String, dynamic>> saveQuizResult({
    required int quizId,
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
    required int totalQuestions,
    required double timeTaken,
    required List<Map<String, dynamic>> questionResults,
  }) async {
    try {
      final url = Uri.parse('$baseUrl?api=save_quiz_result');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'quiz_id': quizId,
              'score': score,
              'correct_answers': correctAnswers,
              'wrong_answers': wrongAnswers,
              'total_questions': totalQuestions,
              'time_taken': timeTaken,
              'question_results': questionResults,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get user quiz stats
  static Future<Map<String, dynamic>> getUserQuizStats() async {
    try {
      final url = Uri.parse('$baseUrl?api=get_user_quiz_stats');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      }
      return _getFallbackUserStats();
    } catch (e) {
      return _getFallbackUserStats();
    }
  }

  static Map<String, dynamic> _getFallbackUserStats() {
    return {
      'total_attempts': 0,
      'average_score': 0,
      'best_score': 0,
      'total_correct': 0,
      'total_questions': 0,
      'quizzes_taken': {},
    };
  }
}
