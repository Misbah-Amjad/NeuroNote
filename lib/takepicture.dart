// lib/takepicture.dart
// Take a Picture screen — captures or picks an image, performs OCR via Groq Vision,
// allows user to review and edit text, and generates polished study resources.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import 'audionoteplayer.dart';
// Import detail screens for direct polished navigation
import 'flashcard_detail.dart';
import 'local_storage_service.dart';
import 'progress_service.dart';
import 'quiz_detail.dart';
import 'summarymindmap_detail.dart';

// ─── Groq config ───────────────────────────────────────────────
const _groqApiKey = '';
const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
const _groqTextModel = 'llama-3.3-70b-versatile';
const _groqVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

Future<String> extractTextFromImageBytes(
  Uint8List bytes,
  String fileName,
) async {
  try {
    final base64Image = base64Encode(bytes);
    final mimeType = _mimeFromName(fileName);
    final response = await http
        .post(
          Uri.parse(_groqEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_groqApiKey',
          },
          body: jsonEncode({
            'model': _groqVisionModel,
            'max_tokens': 1024,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text':
                        'Perform OCR on this image. Extract all readable text. Return only raw extracted text.',
                  },
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (decoded['choices']?[0]?['message']?['content'] as String? ?? '')
          .trim();
    }
  } catch (_) {}
  return 'Could not extract text from image. You can still chat about it.';
}

// ─── Main Screen ───────────────────────────────────────────────
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  State<TakePictureScreen> createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  XFile? _image;
  Uint8List? _imageBytes; // Web/Mobile safe representation
  final ImagePicker _picker = ImagePicker();

  String? _extractedText;
  bool _isExtractingText = false;
  bool _isGenerating = false;
  String _generatingType = '';
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ─── Image picking & OCR triggering ───────────────────────────
  Future<void> _takePicture() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
        _extractText();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera not available: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
        _extractText();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gallery not available: $e')));
      }
    }
  }

  Future<void> _setPickedFile(XFile file) async {
    final bytes = await file.readAsBytes();
    setState(() {
      _image = file;
      _imageBytes = bytes;
      _extractedText = null;
      _textController.clear();
    });
  }

  // ─── OCR: Extract text using Groq Vision API ───────────────────
  Future<void> _extractText() async {
    if (_imageBytes == null) return;

    setState(() {
      _isExtractingText = true;
    });

    try {
      final base64Image = base64Encode(_imageBytes!);
      final mimeType = _getMimeType(_image!.name);

      final response = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: jsonEncode({
              'model': _groqVisionModel,
              'max_tokens': 1024,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text':
                          'Perform OCR on this image. Extract all readable text from it. Do not add any conversational text or comments, return only the raw text extracted. If no text is readable, return "No text found in image."',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$base64Image',
                      },
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        var aiText =
            decoded['choices']?[0]?['message']?['content'] as String? ?? '';
        aiText = aiText.trim();
        if (aiText.startsWith('"') && aiText.endsWith('"')) {
          aiText = aiText.substring(1, aiText.length - 1).trim();
        }

        setState(() {
          _extractedText = aiText;
          _textController.text = aiText;
        });
      } else {
        throw Exception('Vision API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OCR extraction error: $e');
      setState(() {
        _extractedText =
            'Failed to extract text. Please enter study text manually below.';
        _textController.text = '';
      });
    } finally {
      setState(() {
        _isExtractingText = false;
      });
    }
  }

  // ─── AI Study Material Generation ─────────────────────────────
  Future<void> _generateStudyMaterial(String type) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or extract some text first.'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatingType = type;
    });

    try {
      final prompt = _buildPromptForType(type, text);

      final response = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: jsonEncode({
              'model': _groqTextModel,
              'max_tokens': 2048,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final aiText =
            decoded['choices']?[0]?['message']?['content'] as String? ?? '';

        await _saveAndNavigate(type, aiText);
      } else {
        throw Exception('AI chat API returned status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate $type: $e')));
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // ─── Save locally & backend, then navigate ─────────────────────
  Future<void> _saveAndNavigate(String type, String aiText) async {
    try {
      final storageType = _typeToStorageType(type);
      final action = _typeToAction(type);

      List<Map<String, dynamic>> quizQuestions = [];
      if (storageType == 'quiz') {
        quizQuestions = _parseQuizJson(aiText);
      }

      final base64Image = _imageBytes != null
          ? base64Encode(_imageBytes!)
          : null;
      final imageMimeType = _image != null
          ? _getMimeType(_image!.name)
          : 'image/jpeg';

      // Save locally (triggers auto-sync to backend in LocalStorageService)
      final entryId = await LocalStorageService.saveGeneratedContent(
        type: storageType,
        title: '${_capitalize(type)} from Image',
        content: aiText,
        action: action,
        extraData: {
          'source': 'camera',
          if (storageType == 'quiz') 'quiz_data': quizQuestions,
          if (storageType == 'quiz') 'questions': quizQuestions.length,
        },
        imageBase64: base64Image,
        imageMimeType: imageMimeType,
      );

      final entry = {
        'id': entryId,
        'title': '${_capitalize(type)} from Image',
        'content': aiText,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'date':
            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        'source': 'camera',
        if (storageType == 'quiz') 'quiz_data': quizQuestions,
        if (storageType == 'quiz') 'questions': quizQuestions.length,
        'imageBase64': base64Image,
        'imageMimeType': imageMimeType,
      };

      // Record activity progress
      await ProgressService.recordActivity(storageType);

      if (!mounted) return;

      // Direct polished navigation to native screens
      switch (storageType) {
        case 'flashcard':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FlashcardDetailScreen(
                topicTitle: '${_capitalize(type)} from Image',
                topicData: entry,
              ),
            ),
          );
          break;
        case 'quiz':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => QuizDetailScreen(
                topicTitle: '${_capitalize(type)} from Image',
                topicData: entry,
              ),
            ),
          );
          break;
        case 'summary':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SummaryMindMapDetailScreen(
                topicTitle: '${_capitalize(type)} from Image',
                topicData: entry,
              ),
            ),
          );
          break;
        case 'audio_note':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AudioNotePlayerScreen(
                title: 'Audio Note from Image',
                subtitle: 'Generated study script',
                scriptContent: aiText,
              ),
            ),
          );
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved to your library successfully!'),
            ),
          );
          Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save and navigate error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────
  static String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  static String _buildPromptForType(String type, String text) {
    switch (type.toLowerCase()) {
      case 'flashcards':
        return 'You are an expert educator. Create 8–12 study flashcards from the following text. Format each card exactly as:\nQ: [question]\nA: [answer]\n\nDo not add any preamble, markdown blocks, or other text. Here is the source text:\n\n$text';
      case 'summary':
        return 'You are an expert educator. Write a clear, comprehensive study summary of the following text. Use headings and bullet points where appropriate. Do not add any preamble. Here is the source text:\n\n$text';
      case 'mind map':
        return 'You are an expert educator. Create a structured mind map of the following text. Use this exact format:\n# Main Topic\n## Branch 1\n- Sub-point\n- Sub-point\n## Branch 2\n- Sub-point\nDo not add any preamble or markdown blocks. Here is the source text:\n\n$text';
      case 'practice quiz':
        return 'Based on the following study content, create a multiple-choice practice quiz with exactly 5 questions.\n\n'
            'Content:\n$text\n\n'
            'Respond with ONLY valid JSON in exactly this shape, and nothing else:\n'
            '{\n'
            '  "questions": [\n'
            '    {\n'
            '      "question": "string",\n'
            '      "options": ["string", "string", "string", "string"],\n'
            '      "correct": "string (must exactly match one of the options)"\n'
            '    }\n'
            '  ]\n'
            '}\n\n'
            'Rules: exactly 5 questions, exactly 4 options per question, only one correct option, '
            'the "correct" value must be copied exactly from "options", '
            'no markdown formatting, no code fences, no text outside the JSON object.';
      case 'audio notes':
        return 'You are an expert educator. Write a clear, engaging audio script explaining the following text in a conversational, easy-to-follow way as if speaking to a student. Approximately 2-3 minutes long. Here is the source text:\n\n$text';
      default:
        return 'You are an expert educator. Analyze this text and provide study notes. Here is the text:\n\n$text';
    }
  }

  static String _typeToStorageKey(String type) {
    switch (type.toLowerCase()) {
      case 'flashcards':
        return 'flashcards';
      case 'practice quiz':
        return 'quizzes';
      case 'audio notes':
        return 'audio_notes';
      default:
        return 'summaries';
    }
  }

  static String _typeToStorageType(String type) {
    switch (type.toLowerCase()) {
      case 'flashcards':
        return 'flashcard';
      case 'practice quiz':
        return 'quiz';
      case 'audio notes':
        return 'audio_note';
      default:
        return 'summary';
    }
  }

  static String _typeToAction(String type) {
    switch (type.toLowerCase()) {
      case 'mind map':
        return 'mindmap';
      case 'flashcards':
        return 'flashcard';
      case 'practice quiz':
        return 'quiz';
      case 'audio notes':
        return 'audio_note';
      default:
        return 'summary';
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // ─── Quiz Parser from ai_chat.dart ─────────────────────────────
  List<Map<String, dynamic>> _parseQuizJson(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    final jsonMatch = RegExp(
      r'\{[\s\S]*"questions"[\s\S]*\}',
    ).firstMatch(cleaned);
    if (jsonMatch != null) {
      cleaned = jsonMatch.group(0)!;
    }

    try {
      final decoded = jsonDecode(cleaned);
      return _normalizeQuizQuestions(decoded);
    } catch (_) {}

    final listMatch = RegExp(r'r\[[\s\S]*\]').firstMatch(cleaned);
    if (listMatch != null) {
      try {
        return _normalizeQuizQuestions(jsonDecode(listMatch.group(0)!));
      } catch (_) {}
    }

    return [];
  }

  List<Map<String, dynamic>> _normalizeQuizQuestions(dynamic decoded) {
    try {
      final List<dynamic> rawQuestions = decoded is Map
          ? (decoded['questions'] ?? [])
          : (decoded is List ? decoded : []);

      final List<Map<String, dynamic>> result = [];
      for (final q in rawQuestions) {
        if (q is! Map) continue;
        final question = q['question']?.toString().trim() ?? '';
        final options = (q['options'] is List)
            ? List<String>.from(q['options'].map((o) => o.toString().trim()))
            : <String>[];
        var correct = q['correct']?.toString().trim() ?? '';
        if (question.isEmpty || options.length < 4 || correct.isEmpty) {
          continue;
        }
        final fourOptions = options.take(4).toList();
        if (!fourOptions.contains(correct)) {
          final match = fourOptions.firstWhere(
            (o) => o.toLowerCase() == correct.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) correct = match;
        }
        if (!fourOptions.contains(correct)) continue;
        result.add({
          'question': question,
          'options': fourOptions,
          'correct': correct,
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // ─── UI Widgets ────────────────────────────────────────────────
  Widget _buildTopImageHeader() {
    if (_imageBytes == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 70, color: Colors.teal),
          const SizedBox(height: 12),
          Text(
            'Upload your study image to begin',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Support camera capture or gallery selection',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _imageBytes!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              onPressed: () => setState(() {
                _image = null;
                _imageBytes = null;
                _extractedText = null;
                _textController.clear();
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _generateStudyMaterial(title),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Generate Study Content',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Sparkles
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
            ),
          ),

          // Main Scrollable Area
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Section
                  Container(
                    height: _imageBytes == null ? 220 : 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Center(child: _buildTopImageHeader()),
                  ),
                  const SizedBox(height: 20),

                  // Image Selection Buttons
                  if (_imageBytes == null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              'Camera',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _takePicture,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal,
                              side: const BorderSide(
                                color: Colors.teal,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library),
                            label: Text(
                              'Gallery',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _pickFromGallery,
                          ),
                        ),
                      ],
                    ),

                  // OCR Loading State
                  if (_isExtractingText)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Lottie.asset(
                            'assets/animations/Water Splash.json',
                            height: 80,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Extracting text (OCR)...',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // OCR Text Preview and Generation Options
                  if (!_isExtractingText && _imageBytes != null) ...[
                    Text(
                      'Verify Extracted Study Text:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.teal.withOpacity(0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 8,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText:
                              'OCR failed or no text found. Type study content here...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose What to Generate:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.25,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildGenerationCard(
                          'Flashcards',
                          Icons.style,
                          Colors.deepPurple,
                        ),
                        _buildGenerationCard(
                          'Summary',
                          Icons.summarize,
                          Colors.teal,
                        ),
                        _buildGenerationCard(
                          'Mind Map',
                          Icons.account_tree,
                          Colors.pink,
                        ),
                        _buildGenerationCard(
                          'Practice Quiz',
                          Icons.quiz,
                          Colors.blueAccent,
                        ),
                        _buildGenerationCard(
                          'Audio Notes',
                          Icons.mic,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Generation Processing Overlay
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset(
                            'assets/animations/Water Splash.json',
                            height: 120,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Generating $_generatingType...',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.teal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'NeuroNote AI is processing your text study request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
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
