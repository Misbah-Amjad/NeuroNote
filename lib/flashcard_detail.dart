import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:neuronote/premium_screen.dart';

class FlashcardDetailScreen extends StatefulWidget {
  final String topicTitle;
  final Map<String, dynamic>? topicData;

  const FlashcardDetailScreen({
    super.key,
    required this.topicTitle,
    this.topicData,
  });

  @override
  State<FlashcardDetailScreen> createState() => _FlashcardDetailScreenState();
}

class _FlashcardDetailScreenState extends State<FlashcardDetailScreen> {
  List<Map<String, String>> _flashcards = [];

  @override
  void initState() {
    super.initState();
    _parseFlashcards();
  }

  void _parseFlashcards() {
    final content = widget.topicData?['content'] ?? '';
    final cards = <Map<String, String>>[];

    if (content.isNotEmpty) {
      // Try to parse Q&A format
      final lines = content.split('\n');
      String currentQuestion = '';
      String currentAnswer = '';

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('Q:') ||
            trimmed.startsWith('Q.') ||
            trimmed.startsWith('Question:')) {
          // Save previous card if exists
          if (currentQuestion.isNotEmpty && currentAnswer.isNotEmpty) {
            cards.add({'question': currentQuestion, 'answer': currentAnswer});
          }
          // Start new question
          currentQuestion = trimmed
              .replaceFirst(RegExp(r'^Q:?\s*'), '')
              .replaceFirst(RegExp(r'^Question:\s*'), '')
              .trim();
          currentAnswer = '';
        } else if (trimmed.startsWith('A:') ||
            trimmed.startsWith('A.') ||
            trimmed.startsWith('Answer:')) {
          currentAnswer = trimmed
              .replaceFirst(RegExp(r'^A:?\s*'), '')
              .replaceFirst(RegExp(r'^Answer:\s*'), '')
              .trim();
        } else if (trimmed.startsWith('-') || trimmed.startsWith('•')) {
          // Bullet points - append to current answer
          if (currentAnswer.isNotEmpty) {
            currentAnswer += '\n$trimmed';
          } else {
            currentAnswer = trimmed;
          }
        } else if (currentQuestion.isNotEmpty && currentAnswer.isEmpty) {
          // If no A: marker, treat as question continuation
          currentQuestion += ' $trimmed';
        } else if (currentQuestion.isNotEmpty && currentAnswer.isNotEmpty) {
          // Continuation of answer
          currentAnswer += ' $trimmed';
        }
      }

      // Add last card
      if (currentQuestion.isNotEmpty && currentAnswer.isNotEmpty) {
        cards.add({'question': currentQuestion, 'answer': currentAnswer});
      }

      // If no Q&A format found, try to parse as list
      if (cards.isEmpty) {
        final items = content.split('\n\n');
        for (final item in items) {
          final trimmed = item.trim();
          if (trimmed.isEmpty) continue;
          final parts = trimmed.split('\n');
          if (parts.length >= 2) {
            cards.add({
              'question': parts[0].trim(),
              'answer': parts.sublist(1).join('\n').trim(),
            });
          } else {
            // Single item - treat as question with generic answer
            cards.add({
              'question': trimmed,
              'answer': 'Review this flashcard content.',
            });
          }
        }
      }
    }

    // If still no cards, show fallback
    if (cards.isEmpty) {
      cards.add({
        'question': 'No flashcards found in this set',
        'answer': 'Try generating new flashcards from AI Chat.',
      });
    }

    setState(() {
      _flashcards = cards;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCards = _flashcards.length;
    final description =
        widget.topicData?['description'] ?? 'Learn with flashcards';

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Stats Card
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$totalCards',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            'Cards',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.teal.shade200,
                      ),
                      Column(
                        children: [
                          Text(
                            'Category',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            widget.topicData?['category'] ?? 'General',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Flashcard List - Shows real AI-generated content
                ..._flashcards.map((card) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.15),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb,
                              color: Colors.teal,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                card['question']!,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                  fontSize: 14,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card['answer']!,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  );
                }),

                // Premium Section
                Container(
                  margin: const EdgeInsets.only(top: 25, bottom: 30),
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
                        "Want access to more flashcards?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upgrade to Premium to unlock full access and personalized decks!",
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
        ],
      ),
    );
  }
}
