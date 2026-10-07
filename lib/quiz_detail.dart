import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:neuronote/api_service.dart';
import 'quiz_history_service.dart';

class QuizDetailScreen extends StatefulWidget {
  final String topicTitle;
  final Map<String, dynamic>? topicData;

  const QuizDetailScreen({super.key, required this.topicTitle, this.topicData});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  int _currentQuestionIndex = 0;
  String? _selectedOption;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  bool _isAnswered = false;
  bool _isQuizComplete = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _questionResults = [];
  List<Map<String, dynamic>> _quizQuestions = [];
  List<String> _shuffledOptions = [];

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  void _loadQuizData() {
    setState(() => _isLoading = true);

    final quizData = widget.topicData?['quiz_data'] ?? [];
    final totalQuestions = widget.topicData?['questions'] ?? 5;

    if (quizData.isNotEmpty) {
      _quizQuestions = List<Map<String, dynamic>>.from(quizData);
    } else {
      // Generate fallback questions if no data
      _quizQuestions = _generateFallbackQuestions(totalQuestions);
    }

    // Shuffle options for first question
    if (_quizQuestions.isNotEmpty) {
      _shuffleOptionsForQuestion(0);
    }

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _generateFallbackQuestions(int count) {
    final topics = [
      'Biology - Cell Division',
      'Physics - Laws of Motion',
      'Chemistry - Periodic Table',
      'History - World Wars',
      'Mathematics - Algebra',
    ];

    final questions = [
      {
        'question': 'What is the process of cell division called?',
        'options': ['Mitosis', 'Meiosis', 'Both A and B', 'None of the above'],
        'correct': 'Both A and B',
      },
      {
        'question': 'What is Newton\'s Second Law?',
        'options': ['F = ma', 'F = mv', 'E = mc²', 'V = IR'],
        'correct': 'F = ma',
      },
      {
        'question': 'What is the chemical symbol for Gold?',
        'options': ['Au', 'Ag', 'Fe', 'Cu'],
        'correct': 'Au',
      },
      {
        'question': 'What is the powerhouse of the cell?',
        'options': ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi'],
        'correct': 'Mitochondria',
      },
      {
        'question': 'What is the speed of light?',
        'options': ['3×10⁸ m/s', '3×10⁶ m/s', '3×10¹⁰ m/s', '3×10⁴ m/s'],
        'correct': '3×10⁸ m/s',
      },
    ];

    List<Map<String, dynamic>> generated = [];
    for (int i = 0; i < count && i < questions.length; i++) {
      generated.add(questions[i]);
    }
    // Pad with generic questions if needed
    while (generated.length < count) {
      generated.add({
        'question': 'Question ${generated.length + 1}: ${widget.topicTitle}',
        'options': ['Option A', 'Option B', 'Option C', 'Option D'],
        'correct': 'Option A',
      });
    }
    return generated;
  }

  void _shuffleOptionsForQuestion(int index) {
    if (index < _quizQuestions.length) {
      final options = List<String>.from(_quizQuestions[index]['options'] ?? []);
      _shuffledOptions = List.from(options)..shuffle();
    }
  }

  void _selectOption(String option) {
    if (_isAnswered || _isQuizComplete) return;

    setState(() {
      _selectedOption = option;
      _isAnswered = true;

      final correctAnswer =
          _quizQuestions[_currentQuestionIndex]['correct'] ?? '';
      final isCorrect = option == correctAnswer;

      if (isCorrect) {
        _correctAnswers++;
      } else {
        _wrongAnswers++;
      }

      _questionResults.add({
        'question': _quizQuestions[_currentQuestionIndex]['question'],
        'selected': option,
        'correct': correctAnswer,
        'isCorrect': isCorrect,
      });
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _quizQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOption = null;
        _isAnswered = false;
        _shuffleOptionsForQuestion(_currentQuestionIndex);
      });
    } else {
      // Quiz complete - save history
      _saveQuizHistory();
      setState(() {
        _isQuizComplete = true;
      });
    }
  }

  Future<void> _saveQuizHistory() async {
    final quizId = widget.topicData?['id']?.toString() ?? '0';
    final quizTitle = widget.topicTitle;
    final totalQuestions = _quizQuestions.length;
    final score = totalQuestions > 0
        ? (_correctAnswers / totalQuestions * 100).round()
        : 0;

    // Save locally
    try {
      await QuizHistoryService.saveQuizAttempt(
        quizId: quizId,
        quizTitle: quizTitle,
        totalQuestions: totalQuestions,
        correctAnswers: _correctAnswers,
        wrongAnswers: _wrongAnswers,
        questionResults: _questionResults,
        timeTaken: 0,
      );
    } catch (e) {
      print('⚠️ Failed to save quiz history locally: $e');
    }

    // Sync with server
    try {
      await ApiService.saveQuizResult(
        quizId: int.tryParse(quizId) ?? 0,
        score: score,
        correctAnswers: _correctAnswers,
        wrongAnswers: _wrongAnswers,
        totalQuestions: totalQuestions,
        timeTaken: 0,
        questionResults: _questionResults,
      );
      print('✅ Quiz result synced with server');
    } catch (e) {
      print('⚠️ Failed to sync quiz result: $e');
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedOption = null;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _isAnswered = false;
      _isQuizComplete = false;
      _questionResults = [];
      _shuffleOptionsForQuestion(0);
    });
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: QuizHistoryService.getQuizHistoryByQuizId(
            widget.topicData?['id']?.toString() ?? '',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.teal),
              );
            }

            final history = snapshot.data ?? [];
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📊 Quiz History',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 50,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No history yet',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                'Complete this quiz to track your progress!',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final attempt = history[index];
                            final score = attempt['score'] as int? ?? 0;
                            final date = DateTime.parse(
                              attempt['timestamp'] ??
                                  DateTime.now().toIso8601String(),
                            );
                            final correct =
                                attempt['correctAnswers'] as int? ?? 0;
                            final total =
                                attempt['totalQuestions'] as int? ?? 0;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: score >= 70
                                      ? Colors.green.shade200
                                      : score >= 40
                                      ? Colors.orange.shade200
                                      : Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: score >= 70
                                          ? Colors.green.shade100
                                          : score >= 40
                                          ? Colors.orange.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$score%',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: score >= 70
                                              ? Colors.green.shade700
                                              : score >= 40
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(date),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a').format(date),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        Text(
                                          '$correct/$total correct',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    score >= 70
                                        ? Icons.star
                                        : score >= 40
                                        ? Icons.star_half
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _quizQuestions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.topicTitle,
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.teal),
            onPressed: _showHistory,
            tooltip: 'View History',
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
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal))
          else if (_quizQuestions.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No questions available',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (_isQuizComplete)
            _buildResultScreen()
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildQuizScreen(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    final question = _quizQuestions[_currentQuestionIndex];
    final totalQuestions = _quizQuestions.length;
    final progress = (_currentQuestionIndex + 1) / totalQuestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/$totalQuestions',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.teal.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Score indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_correctAnswers',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.cancel, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_wrongAnswers',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Question Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question['question'] ?? 'No question available',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Options
        Expanded(
          child: ListView.builder(
            itemCount: _shuffledOptions.length,
            itemBuilder: (context, index) {
              final option = _shuffledOptions[index];
              final isSelected = _selectedOption == option;
              final correctAnswer = question['correct'] ?? '';
              bool isCorrect = false;
              bool isWrong = false;

              if (_isAnswered) {
                isCorrect = option == correctAnswer;
                isWrong = isSelected && option != correctAnswer;
              }

              return GestureDetector(
                onTap: () => _selectOption(option),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _isAnswered
                        ? (isCorrect
                              ? Colors.green.shade50
                              : isWrong
                              ? Colors.red.shade50
                              : Colors.white)
                        : (isSelected ? Colors.teal.shade50 : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isAnswered
                          ? (isCorrect
                                ? Colors.green.shade400
                                : isWrong
                                ? Colors.red.shade400
                                : Colors.grey.shade300)
                          : (isSelected ? Colors.teal : Colors.grey.shade300),
                      width: _isAnswered ? 2 : (isSelected ? 2 : 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _isAnswered
                              ? (isCorrect
                                    ? Colors.green
                                    : isWrong
                                    ? Colors.red
                                    : Colors.grey.shade300)
                              : (isSelected
                                    ? Colors.teal
                                    : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              color: _isAnswered
                                  ? (isCorrect || isWrong
                                        ? Colors.white
                                        : Colors.black54)
                                  : (isSelected
                                        ? Colors.white
                                        : Colors.black54),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: _isAnswered
                                ? (isCorrect
                                      ? Colors.green.shade700
                                      : isWrong
                                      ? Colors.red.shade700
                                      : Colors.black87)
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (_isAnswered && isCorrect)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 22,
                        ),
                      if (_isAnswered && isWrong)
                        const Icon(Icons.cancel, color: Colors.red, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Next Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAnswered ? Colors.teal : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: _isAnswered ? 2 : 0,
            ),
            onPressed: _isAnswered ? _nextQuestion : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentQuestionIndex < _quizQuestions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: GoogleFonts.poppins(
                    color: _isAnswered ? Colors.white : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_isAnswered) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _currentQuestionIndex < _quizQuestions.length - 1
                        ? Icons.arrow_forward
                        : Icons.assessment,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    final totalQuestions = _quizQuestions.length;
    final score = totalQuestions > 0
        ? (_correctAnswers / totalQuestions * 100).round()
        : 0;

    String performance = '';
    IconData performanceIcon = Icons.sentiment_neutral;
    Color performanceColor = Colors.grey;
    String emoji = '😐';

    if (score >= 80) {
      performance = 'Excellent!';
      performanceIcon = Icons.emoji_events;
      performanceColor = Colors.amber;
      emoji = '🌟';
    } else if (score >= 60) {
      performance = 'Good Job!';
      performanceIcon = Icons.thumb_up;
      performanceColor = Colors.green;
      emoji = '💪';
    } else if (score >= 40) {
      performance = 'Keep Practicing!';
      performanceIcon = Icons.school;
      performanceColor = Colors.orange;
      emoji = '📚';
    } else {
      performance = 'Review and Try Again!';
      performanceIcon = Icons.refresh;
      performanceColor = Colors.red;
      emoji = '🔄';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Result Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 50)),
                const SizedBox(height: 8),
                Text(
                  performance,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You got $score%',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultStat('Score', '$score%', Colors.white),
                    _buildResultStat(
                      'Correct',
                      '$_correctAnswers',
                      Colors.green.shade200,
                    ),
                    _buildResultStat(
                      'Wrong',
                      '$_wrongAnswers',
                      Colors.red.shade200,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Performance Breakdown
          if (_questionResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Performance Breakdown',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._questionResults.asMap().entries.map((entry) {
                    final index = entry.key;
                    final result = entry.value;
                    final isCorrect = result['isCorrect'] ?? false;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              result['question'] ?? 'Question',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _resetQuiz,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Colors.teal),
                  ),
                  onPressed: _showHistory,
                  icon: const Icon(Icons.history, color: Colors.teal),
                  label: Text(
                    'History',
                    style: GoogleFonts.poppins(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
