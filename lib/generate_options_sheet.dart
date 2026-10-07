// lib/widgets/generate_options_sheet.dart
import 'package:flutter/material.dart';
import 'package:neuronote/ai_chat.dart';

class GenerateOptionsSheet {
  // ─── Show options sheet with custom builder for UI ──────────
  static void showWithCustomBuilder(
    BuildContext context, {
    required String title,
    required String content,
    required Widget Function(
      BuildContext context,
      StateSetter setState,
      bool generateFlashcards,
      bool generateAudioNote,
      bool generateSummaryMindMap,
      bool generatePracticeQuiz,
      VoidCallback toggleFlashcards,
      VoidCallback toggleAudioNote,
      VoidCallback toggleSummaryMindMap,
      VoidCallback togglePracticeQuiz,
    )
    builder,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            bool _generateFlashcards = false;
            bool _generateAudioNote = false;
            bool _generateSummaryMindMap = false;
            bool _generatePracticeQuiz = false;

            void _toggleFlashcards() {
              setStateBottomSheet(() {
                _generateFlashcards = !_generateFlashcards;
              });
            }

            void _toggleAudioNote() {
              setStateBottomSheet(() {
                _generateAudioNote = !_generateAudioNote;
              });
            }

            void _toggleSummaryMindMap() {
              setStateBottomSheet(() {
                _generateSummaryMindMap = !_generateSummaryMindMap;
              });
            }

            void _togglePracticeQuiz() {
              setStateBottomSheet(() {
                _generatePracticeQuiz = !_generatePracticeQuiz;
              });
            }

            bool _isAnyOptionSelected() {
              return _generateFlashcards ||
                  _generateAudioNote ||
                  _generateSummaryMindMap ||
                  _generatePracticeQuiz;
            }

            void _processSelectedOptions() {
              Navigator.pop(context);

              String action = '';
              String actionContent = '';

              if (_generateSummaryMindMap) {
                action = 'summarize';
                actionContent = 'Create summary and mind map for: $content';
              } else if (_generateAudioNote) {
                action = 'voice';
                actionContent = 'Create audio note for: $content';
              } else if (_generateFlashcards) {
                action = 'flashcard';
                actionContent = 'Create flashcards for: $content';
              } else if (_generatePracticeQuiz) {
                action = 'quiz';
                actionContent = 'Create practice quiz for: $content';
              }

              if (action.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIChatScreen(
                      initialAction: action,
                      initialContent: actionContent,
                    ),
                  ),
                );
              }
            }

            return builder(
              context,
              setStateBottomSheet,
              _generateFlashcards,
              _generateAudioNote,
              _generateSummaryMindMap,
              _generatePracticeQuiz,
              _toggleFlashcards,
              _toggleAudioNote,
              _toggleSummaryMindMap,
              _togglePracticeQuiz,
            );
          },
        );
      },
    );
  }
}
