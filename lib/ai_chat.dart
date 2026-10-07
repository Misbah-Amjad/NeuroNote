import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:neuronote/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'backend_service.dart';
import 'document_text_extractor.dart';
import 'navigation.dart';
import 'save.dart';

// ─── Groq config ───────────────────────────────────────────────
const _groqApiKey = '';
const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
const _groqModel = 'llama-3.3-70b-versatile';
const _groqVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
const _maxVisionImageBytes = 3 * 1024 * 1024;
const _geminiApiKey = '';
const _geminiImageModels = ['gemini-3.1-flash-image', 'gemini-2.5-flash-image'];
const _historyKey = 'neuronote_ai_chat_history';
const _chatHistoryListKey = 'chat_history_list';

// ─── Chat History Models ──────────────────────────────────────

class ChatHistory {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime timestamp;
  final int messageCount;

  ChatHistory({
    required this.id,
    required this.title,
    required this.messages,
    required this.timestamp,
    required this.messageCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'messageCount': messageCount,
  };

  factory ChatHistory.fromJson(Map<String, dynamic> json) => ChatHistory(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List)
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    timestamp: DateTime.parse(json['timestamp']),
    messageCount: json['messageCount'],
  );
}

// ─── Main AIChatScreen ──────────────────────────────────────

class AIChatScreen extends StatefulWidget {
  final String? initialAction;
  final String? initialContent;
  final String? uploadedFileName;
  final String? uploadedFileContent;
  final bool returnToUploadOnBack;

  const AIChatScreen({
    super.key,
    this.initialAction,
    this.initialContent,
    this.uploadedFileName,
    this.uploadedFileContent,
    this.returnToUploadOnBack = false,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final ImagePicker _imagePicker = ImagePicker();
  bool _loading = false;
  bool _isProcessingFile = false;
  bool _waitingForAction = false;
  String? _currentlyPlayingId;

  // File upload states
  PlatformFile? _selectedFile;
  String? _uploadedFileName;
  String? _fileContent;
  String? _currentFileType;

  // Camera image states
  XFile? _capturedImage;
  Uint8List? _capturedImageBytes;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _clearCurrentChat();
    _initTts();

    final hasUploadedFile =
        widget.uploadedFileName != null && widget.uploadedFileContent != null;
    final hasInitialAction = widget.initialAction != null;

    // ─── Show modal when coming from Upload Content ────────────
    if (hasUploadedFile && widget.initialAction == 'show_modal') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _uploadedFileName = widget.uploadedFileName;
        _fileContent = widget.uploadedFileContent;
        _showFilePreview('📄 ${widget.uploadedFileName}');
        BackendService.saveDocument(
          fileName: widget.uploadedFileName!,
          fileType: 'image',
          extractedText: widget.uploadedFileContent ?? '',
        );
      });
    } else if (hasUploadedFile &&
        hasInitialAction &&
        widget.initialAction != 'show_modal') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleUploadedFileWithAction(
          widget.uploadedFileName!,
          widget.uploadedFileContent!,
          widget.initialAction!,
        );
      });
    } else if (hasUploadedFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleUploadedFile(
          widget.uploadedFileName!,
          widget.uploadedFileContent!,
        );
      });
    } else if (hasInitialAction && widget.initialAction != 'show_modal') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInitialAction(
          widget.initialAction!,
          widget.initialContent ?? '',
        );
      });
    }
  }

  Future<void> _handleUploadedFileWithAction(
    String fileName,
    String fileContent,
    String action,
  ) async {
    if (!DocumentTextExtractor.isUsableContent(fileContent)) {
      _addMessage('📄 Uploaded: $fileName', true);
      _addMessage(
        '⚠️ Could not read this document. Please upload a text-based PDF or TXT file.',
        false,
      );
      return;
    }

    setState(() {
      _uploadedFileName = fileName;
      _fileContent = fileContent;
    });

    _addMessage('📄 Uploaded: $fileName', true);
    await _processUploadedFile(action);
  }

  Future<void> _clearCurrentChat() async {
    setState(() {
      _messages.clear();
    });
    await _saveHistory();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _currentlyPlayingId = null);
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() => _currentlyPlayingId = null);
        }
      });
    } catch (e) {
      print('TTS Init Error');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ─── Handle Uploaded File from External Screen ──────────────

  Future<void> _handleUploadedFile(String fileName, String fileContent) async {
    setState(() {
      _uploadedFileName = fileName;
      _fileContent = fileContent;
      _waitingForAction = true;
    });

    _addMessage('📄 Uploaded: $fileName', true);
    _addMessage(
      '📄 I see you uploaded "$fileName". What would you like me to do with it?',
      false,
    );
  }

  // ─── History Methods ──────────────────────────────────────────

  Future<List<ChatHistory>> _getChatHistories() async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = await AuthService.scopedKey(_chatHistoryListKey);
    final String? data = prefs.getString(listKey);
    if (data == null) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list
          .map((h) => ChatHistory.fromJson(Map<String, dynamic>.from(h)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveCurrentChat() async {
    if (_messages.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final histories = await _getChatHistories();

    String title = 'New Chat';
    for (final msg in _messages) {
      if (msg.isUser && msg.text.isNotEmpty) {
        title = msg.text.length > 30
            ? '${msg.text.substring(0, 30)}...'
            : msg.text;
        break;
      }
    }

    final history = ChatHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      messages: List.from(_messages),
      timestamp: DateTime.now(),
      messageCount: _messages.length,
    );

    histories.insert(0, history);
    final listKey = await AuthService.scopedKey(_chatHistoryListKey);
    await prefs.setString(
      listKey,
      jsonEncode(histories.map((h) => h.toJson()).toList()),
    );

    await BackendService.saveChat(
      sessionId: history.id,
      title: history.title,
      messages: history.messages.map((m) => m.toJson()).toList(),
    );

    setState(() {
      _messages.clear();
    });
    await _saveHistory();
    _showInfoSnackBar('Chat saved to history');
  }

  Future<void> _deleteHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final histories = await _getChatHistories();
    final updated = histories.where((h) => h.id != id).toList();
    final listKey = await AuthService.scopedKey(_chatHistoryListKey);
    await prefs.setString(
      listKey,
      jsonEncode(updated.map((h) => h.toJson()).toList()),
    );
    if (mounted) {
      setState(() {});
      _showInfoSnackBar('Chat deleted');
    }
  }

  Future<void> _loadHistoryChat(ChatHistory history) async {
    setState(() {
      _messages.clear();
      _messages.addAll(history.messages);
    });
    await _saveHistory();
    _scrollDown();
    Navigator.pop(context);
    _showInfoSnackBar('Loaded: ${history.title}');
  }

  void _showHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
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
                    'Chat History',
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
              child: FutureBuilder<List<ChatHistory>>(
                future: _getChatHistories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    );
                  }

                  final histories = snapshot.data ?? [];

                  if (histories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 50,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No chat history',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a new conversation!',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: histories.length,
                    itemBuilder: (context, index) {
                      final history = histories[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              history.messages.last.isUser
                                  ? Icons.person_outline
                                  : Icons.auto_awesome,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            history.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                '${history.messageCount} msgs',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(history.timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteHistory(history.id),
                          ),
                          onTap: () => _loadHistoryChat(history),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // ─── Camera Methods ──────────────────────────────────────────

  Future<void> _captureImage() async {
    try {
      XFile? image;

      if (kIsWeb) {
        image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 60,
        );
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 60,
        );
      }

      if (image != null) {
        setState(() {
          _capturedImage = image;
          _isProcessingImage = true;
        });

        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
        });

        _showImagePreviewDialog(image);
      }
    } catch (e) {
      _showErrorSnackBar('Error accessing camera: ${e.toString()}');
    }
  }

  void _showImagePreviewDialog(XFile image) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.image, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '📸 Captured Image',
                style: GoogleFonts.poppins(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: _capturedImageBytes != null
                      ? MemoryImage(_capturedImageBytes!)
                      : (kIsWeb
                            ? NetworkImage(image.path)
                            : FileImage(File(image.path)) as ImageProvider),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like AI to do with this image?',
              style: GoogleFonts.poppins(
                color: Colors.teal.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildImageActionButton(
                    '📝 Summary & Mind Map',
                    () => _processImageWithAI('summary_mindmap'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildImageActionButton(
                    '🧠 Explain',
                    () => _processImageWithAI('explain'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildImageActionButton(
                    '🎧 Voice Note',
                    () => _processImageWithAI('voice'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildImageActionButton(
                    '📝 Practice Quiz',
                    () => _processImageWithAI('quiz'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _clearCapturedImage();
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processImageWithAI(String action) async {
    if (_capturedImage == null) {
      _showErrorSnackBar('No image to process');
      return;
    }

    Navigator.pop(context);

    setState(() {
      _isProcessingImage = true;
      _loading = true;
    });

    _addMessage('📸 Captured image for: ${_getActionLabel(action)}', true);

    final prepared = await _prepareImageForGroq(
      await _capturedImage!.readAsBytes(),
    );
    final base64Image = base64Encode(prepared.bytes);
    final mimeType = prepared.mimeType == 'image/jpeg'
        ? _imageMimeType(_capturedImage!)
        : prepared.mimeType;
    final textPrompt =
        '${_getImageSystemPrompt(action)}\n\n${_buildImagePrompt(action)}';

    try {
      final res = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _groqVisionModel,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': textPrompt},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$base64Image',
                      },
                    },
                  ],
                },
              ],
              'temperature': 0.5,
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = _extractReply(data);
        if (reply.isNotEmpty) {
          String displayText = '';
          String storageType = '';
          String storageTitle = '';
          String? imageBase64;
          String? imageMimeType;
          String? imageUrl;

          if (action == 'voice') {
            displayText = '🎧 ${_formatVoiceNote(reply)}';
            storageType = 'audio_note';
            storageTitle = 'Audio Note from Image';

            // ─── SAVE AUDIO NOTE ──────────────────────────────────
            String preview = _cleanPreviewForAudio(reply);
            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {'source': 'Image Capture', 'preview': preview},
            );
            _showInfoSnackBar('✅ Content saved to Audio Notes');
          } else if (action == 'all') {
            displayText = '📚 ${_formatAllResponse(reply)}';
            storageType = 'summary';
            storageTitle = 'Full Analysis from Image';

            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'source': 'Image Capture',
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          } else if (action == 'quiz') {
            final quizQuestions = _parseQuizJson(reply);
            storageType = 'quiz';
            storageTitle = 'Quiz from Image';
            displayText = quizQuestions.isEmpty
                ? '⚠️ Could not generate a valid quiz from this image. Please try again.'
                : '📝 Practice quiz ready: ${quizQuestions.length} questions. Open it from Practice Quizzes to start.';

            if (quizQuestions.isNotEmpty) {
              await LocalStorageService.saveGeneratedContent(
                type: storageType,
                title: storageTitle,
                content: reply,
                action: action,
                extraData: {
                  'source': 'Image Capture',
                  'preview': '${quizQuestions.length} questions',
                  'questions': quizQuestions.length,
                  'quiz_data': quizQuestions,
                },
              );
              _showInfoSnackBar(
                '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
              );
            }
          } else {
            String prefix = '';
            switch (action) {
              case 'summarize':
                prefix = '📝 Summary:\n';
                storageType = 'summary';
                storageTitle = 'Summary from Image';
                break;
              case 'summary_mindmap':
                prefix = '📝 Summary & 🗺️ Mind Map:\n';
                storageType = 'summary';
                storageTitle = 'Summary & Mind Map from Image';
                break;
              case 'explain':
                prefix = '🧠 Explanation:\n';
                storageType = 'summary';
                storageTitle = 'Explanation from Image';
                break;
              case 'mindmap':
                prefix = '🗺️ Mind Map:\n';
                storageType = 'summary';
                storageTitle = 'Mind Map from Image';
                break;
              case 'flashcard':
                prefix = '📚 Flashcards:\n';
                storageType = 'flashcard';
                storageTitle = 'Flashcards from Image';
                break;
              default:
                prefix = '';
                storageType = 'summary';
                storageTitle = 'Content from Image';
            }
            displayText = prefix + reply;

            if (action == 'summarize' ||
                action == 'summary_mindmap' ||
                action == 'mindmap') {
              final imageData = await _generateSummaryImageData(
                reply,
                action: action,
              );
              imageBase64 = imageData?.$1;
              imageMimeType = imageData?.$2;
              imageUrl = imageData?.$3;
            }

            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'source': 'Image Capture',
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
              imageBase64: imageBase64,
              imageMimeType: imageMimeType,
              imageUrl: imageUrl,
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          }

          _addMessage(displayText, false);
          if ((action == 'summarize' ||
                  action == 'summary_mindmap' ||
                  action == 'mindmap') &&
              (imageBase64 != null || imageUrl != null)) {
            _addMessage(
              '🖼️ Visual summary',
              false,
              imageBase64: imageBase64,
              imageMimeType: imageMimeType,
              imageUrl: imageUrl,
              retrySummaryText: reply,
            );
          }

          if (action == 'voice' || action == 'all') {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _messages.isNotEmpty) {
                final lastMsg = _messages.last;
                _speakText(lastMsg.text, lastMsg.id);
              }
            });
          }
        } else {
          _addMessage('No response received.', false);
        }
      } else {
        _addMessage(_parseApiError(res), false);
      }
    } catch (e) {
      _addMessage(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isProcessingImage = false;
        });
      }
      _clearCapturedImage();
    }
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'summarize':
        return 'Summarize';
      case 'summary_mindmap':
        return 'Summary & Mind Map';
      case 'explain':
        return 'Explain';
      case 'mindmap':
        return 'Mind Map';
      case 'voice':
        return 'Voice Note';
      case 'quiz':
        return 'Practice Quiz';
      case 'all':
        return 'All';
      default:
        return 'Process';
    }
  }

  String _buildImagePrompt(String action) {
    String prompt = 'I have captured an image. ';

    switch (action) {
      case 'summarize':
        prompt +=
            'Please analyze this image and provide a comprehensive summary of what you see.';
        break;
      case 'summary_mindmap':
        prompt +=
            'Please analyze this image and provide BOTH:\n1. A clear summary with key points\n2. A mind map structure with main topics, subtopics, and key points using indentation.\nLabel each section clearly.';
        break;
      case 'explain':
        prompt +=
            'Please explain what is in this image in simple, easy-to-understand language.';
        break;
      case 'mindmap':
        prompt +=
            'Please create a mind map structure based on the content of this image.';
        break;
      case 'voice':
        prompt +=
            'Please create a conversational voice note script based on what you see in this image.';
        break;
      case 'quiz':
        prompt +=
            'Please create a multiple-choice practice quiz with 5 to 8 questions based on what you see in this image. '
            'Respond with ONLY valid JSON in exactly this shape, and nothing else:\n'
            '{"questions": [{"question": "string", "options": ["string","string","string","string"], "correct": "string (must exactly match one of the options)"}]}\n'
            'Exactly 4 options per question, only one correct option, the "correct" value copied exactly from "options", no markdown, no text outside the JSON object.';
        break;
      case 'all':
        prompt +=
            'Please provide ALL of the following based on this image:\n1. 📝 Summary\n2. 🧠 Explanation\n3. 🗺️ Mind Map\n4. 🎧 Voice Note Script\n5. 📚 Flashcards\n\nOrganize each section clearly.';
        break;
      default:
        prompt += 'Please analyze this image.';
    }

    return prompt;
  }

  String _getImageSystemPrompt(String action) {
    switch (action) {
      case 'voice':
        return 'You are a podcast script writer. Analyze images and create engaging voice note scripts.';
      case 'explain':
        return 'You are a patient teacher. Explain visual content simply with clear descriptions.';
      case 'mindmap':
        return 'You are an expert at organizing information from images into hierarchical structures.';
      case 'summary_mindmap':
        return 'You are an expert educator. Analyze images and provide both a clear summary and a hierarchical mind map.';
      case 'quiz':
        return 'You are a quiz generator. You ONLY respond with valid JSON, no extra commentary, no markdown code fences, no explanations before or after. Your entire response must be a single parseable JSON object.';
      default:
        return 'You are NeuroNote AI, a helpful study assistant. Analyze images and provide clear, structured responses.';
    }
  }

  void _clearCapturedImage() {
    setState(() {
      _capturedImage = null;
      _capturedImageBytes = null;
      _isProcessingImage = false;
    });
  }

  // ─── File Upload Methods ──────────────────────────────────────

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _uploadedFileName = file.name;
          _fileContent = null;
          _currentFileType = file.extension?.toLowerCase() ?? 'unknown';
        });

        if (file.bytes != null) {
          final extracted = await DocumentTextExtractor.extract(
            file.name,
            file.bytes!,
          );
          if (DocumentTextExtractor.isUsableContent(extracted)) {
            _fileContent = extracted;
          } else {
            _fileContent =
                'Could not extract readable text from "${file.name}". '
                'Try a text-based PDF or TXT file.';
          }
        } else if (!kIsWeb && file.path != null) {
          final fileObj = File(file.path!);
          final bytes = await fileObj.readAsBytes();
          final extracted = await DocumentTextExtractor.extract(
            file.name,
            bytes,
          );
          _fileContent = DocumentTextExtractor.isUsableContent(extracted)
              ? extracted
              : 'Could not extract readable text from "${file.name}".';
        }

        _showFilePreview('📄 ${file.name}');
        if (_fileContent != null) {
          String? fileBase64;
          if (file.bytes != null) {
            fileBase64 = base64Encode(file.bytes!);
          }
          BackendService.saveDocument(
            fileName: file.name,
            fileType: _currentFileType ?? 'document',
            extractedText: _fileContent!,
            fileBase64: fileBase64,
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking document');
    }
  }

  void _clearUploadedFile() {
    setState(() {
      _selectedFile = null;
      _uploadedFileName = null;
      _fileContent = null;
      _currentFileType = null;
      _waitingForAction = false;
    });
    _showInfoSnackBar('File cleared');
  }

  // ─── File Preview Modal ──────────────────────────────────────

  void _showFilePreview(String title) {
    bool generateFlashcards = false;
    bool generateAudioNote = false;
    bool generateSummaryMindMap = false;
    bool generatePracticeQuiz = false;

    void toggleOption(String option, StateSetter setStateBottomSheet) {
      setStateBottomSheet(() {
        switch (option) {
          case 'flashcards':
            generateFlashcards = !generateFlashcards;
            break;
          case 'audionote':
            generateAudioNote = !generateAudioNote;
            break;
          case 'summarymindmap':
            generateSummaryMindMap = !generateSummaryMindMap;
            break;
          case 'practicequiz':
            generatePracticeQuiz = !generatePracticeQuiz;
            break;
        }
      });
    }

    bool isAnyOptionSelected() {
      return generateFlashcards ||
          generateAudioNote ||
          generateSummaryMindMap ||
          generatePracticeQuiz;
    }

    void processSelectedOptions() {
      Navigator.pop(context);

      String action = '';
      if (generateSummaryMindMap) {
        action = 'summary_mindmap';
      } else if (generateAudioNote) {
        action = 'voice';
      } else if (generateFlashcards) {
        action = 'flashcard';
      } else if (generatePracticeQuiz) {
        action = 'quiz';
      }

      if (action.isNotEmpty && _fileContent != null) {
        _handleUploadedFileWithAction(
          _uploadedFileName ?? 'Document',
          _fileContent!,
          action,
        );
      }
    }

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
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Choose What to Generate",
                        style: GoogleFonts.poppins(
                          color: Colors.teal,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          Navigator.pop(context);
                          _clearUploadedFile();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _uploadedFileName ?? 'No file selected',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_uploadedFileName != null)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.teal,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildOptionTile(
                    label: "Generate Flashcards",
                    icon: Icons.style,
                    color: Colors.deepPurple,
                    isSelected: generateFlashcards,
                    onTap: () =>
                        toggleOption('flashcards', setStateBottomSheet),
                  ),
                  _buildOptionTile(
                    label: "Generate AudioNote",
                    icon: Icons.mic,
                    color: Colors.orange,
                    isSelected: generateAudioNote,
                    onTap: () => toggleOption('audionote', setStateBottomSheet),
                  ),
                  _buildOptionTile(
                    label: "Generate Summary & Mindmaps",
                    icon: Icons.summarize,
                    color: Colors.teal,
                    isSelected: generateSummaryMindMap,
                    onTap: () =>
                        toggleOption('summarymindmap', setStateBottomSheet),
                  ),
                  _buildOptionTile(
                    label: "Generate Practice Quiz",
                    icon: Icons.quiz,
                    color: Colors.blueAccent,
                    isSelected: generatePracticeQuiz,
                    onTap: () =>
                        toggleOption('practicequiz', setStateBottomSheet),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isAnyOptionSelected()
                          ? processSelectedOptions
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Generate",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionTile({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade800),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.teal, size: 24)
          : null,
      onTap: onTap,
      visualDensity: VisualDensity.compact,
      dense: true,
    );
  }

  Widget _buildActionChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.teal.shade50,
      labelStyle: TextStyle(color: Colors.teal.shade700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal.shade200),
      ),
    );
  }

  Widget _buildImageActionButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.teal.shade700,
          side: BorderSide(color: Colors.teal.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── Helper: Clean Preview for Audio Notes ───────────────────

  String _cleanPreviewForAudio(String text) {
    String cleaned = text
        .replaceAll('🎧', '')
        .replaceAll('🔹 Voice Note Generated', '')
        .replaceAll('Voice Note Generated', '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'#.*?\n'), '')
        .trim();
    if (cleaned.length > 100) {
      cleaned = '${cleaned.substring(0, 100)}...';
    }
    return cleaned;
  }

  // ─── Text-to-Speech Methods ──────────────────────────────────

  Future<void> _speakText(String text, String messageId) async {
    if (text.isEmpty) {
      _showErrorSnackBar('No text to speak');
      return;
    }

    if (_currentlyPlayingId == messageId) {
      await _flutterTts.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    try {
      if (_currentlyPlayingId != null) {
        await _flutterTts.stop();
      }

      setState(() => _currentlyPlayingId = messageId);

      String cleanText = text
          .replaceAll(RegExp(r'[📝🧠🗺️🎧📚🔹🔸▶️]'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'#.*?\n'), '')
          .trim();

      if (cleanText.length > 800) {
        cleanText = '${cleanText.substring(0, 800)}...';
      }

      if (kIsWeb) {
        await _flutterTts.stop();
      }
      await _flutterTts.speak(cleanText);
    } catch (e) {
      setState(() => _currentlyPlayingId = null);
      if (!kIsWeb) {
        _showErrorSnackBar('Error playing voice');
      }
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _flutterTts.stop();
      setState(() => _currentlyPlayingId = null);
      _showInfoSnackBar('Voice playback stopped');
    } catch (e) {
      print('Stop Error');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showInfoSnackBar('📋 Copied to clipboard!');
  }

  // ─── Process File with AI ─────────────────────────────────────

  Future<void> _processFileWithAI(String action) async {
    if (_selectedFile == null) {
      _showErrorSnackBar('No document to process');
      return;
    }

    setState(() {
      _isProcessingFile = true;
      _loading = true;
      _waitingForAction = false;
    });

    String content = _buildActionPrompt(action);
    final String sourceFileName = _uploadedFileName ?? 'Document';
    _addMessage('📄 Processing: $sourceFileName', true);
    _clearUploadedFile();

    try {
      final res = await _callGroqChat(
        action: action,
        systemPrompt: _getSystemPrompt(action),
        userContent: content,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = _extractReply(data);
        if (reply.isNotEmpty) {
          String storageType = '';
          String storageTitle = '';

          if (action == 'voice') {
            _addMessage('🎧 ${_formatVoiceNote(reply)}', false);
            storageType = 'audio_note';
            storageTitle = 'Audio Note: $sourceFileName';

            String preview = _cleanPreviewForAudio(reply);
            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {'sourceFile': sourceFileName, 'preview': preview},
            );
            _showInfoSnackBar('✅ Content saved to Audio Notes');
          } else if (action == 'all') {
            _addMessage('📚 ${_formatAllResponse(reply)}', false);
            storageType = 'summary';
            storageTitle = 'Full Analysis: $sourceFileName';

            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'sourceFile': sourceFileName,
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          } else if (action == 'quiz') {
            final quizQuestions = _parseQuizJson(reply);
            storageType = 'quiz';
            storageTitle = 'Quiz: $sourceFileName';
            if (quizQuestions.isEmpty) {
              _addMessage(
                '⚠️ Could not generate a valid quiz from this document. Please try again.',
                false,
              );
            } else {
              _addMessage(
                '📝 Practice quiz ready: ${quizQuestions.length} questions on "$sourceFileName". Open it from Practice Quizzes to start.',
                false,
              );

              await LocalStorageService.saveGeneratedContent(
                type: storageType,
                title: storageTitle,
                content: reply,
                action: action,
                extraData: {
                  'sourceFile': sourceFileName,
                  'preview': '${quizQuestions.length} questions',
                  'questions': quizQuestions.length,
                  'quiz_data': quizQuestions,
                },
              );
              _showInfoSnackBar(
                '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
              );
            }
          } else {
            _addMessage(reply, false);
            switch (action) {
              case 'summarize':
                storageType = 'summary';
                storageTitle = 'Summary: $sourceFileName';
                break;
              case 'summary_mindmap':
                storageType = 'summary';
                storageTitle = 'Summary & Mind Map: $sourceFileName';
                break;
              case 'explain':
                storageType = 'summary';
                storageTitle = 'Explanation: $sourceFileName';
                break;
              case 'mindmap':
                storageType = 'summary';
                storageTitle = 'Mind Map: $sourceFileName';
                break;
              case 'flashcard':
                storageType = 'flashcard';
                storageTitle = 'Flashcards: $sourceFileName';
                break;
              default:
                storageType = 'summary';
                storageTitle = 'Content: $sourceFileName';
            }

            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'sourceFile': sourceFileName,
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );

            if (_shouldAutoGenerateImage(action)) {
              await _maybeGenerateSummaryImage(
                reply,
                action: action,
                storageTitle: storageTitle,
              );
            }
          }

          if (action == 'voice' || action == 'all') {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _messages.isNotEmpty) {
                final lastMsg = _messages.last;
                _speakText(lastMsg.text, lastMsg.id);
              }
            });
          }
        } else {
          _addMessage('No response received.', false);
        }
      } else {
        _addMessage(_parseApiError(res), false);
      }
    } catch (e) {
      _addMessage(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isProcessingFile = false;
        });
      }
    }
  }

  String _formatVoiceNote(String text) {
    return '🔹 Voice Note Generated\n\n$text';
  }

  String _formatAllResponse(String text) {
    return '🔹 Complete Analysis\n\n$text';
  }

  String _buildActionPrompt(String action) {
    if (_fileContent == null ||
        !DocumentTextExtractor.isUsableContent(_fileContent)) {
      return 'The uploaded file could not be read. Ask for a text-based PDF or TXT.';
    }

    String baseContent =
        'I uploaded a document named ${_uploadedFileName ?? "document"}. '
        'The full extracted text is below — use it directly. '
        'Do not say you cannot access the file.\n\n';
    String content = DocumentTextExtractor.prepareForAi(_fileContent!);
    baseContent += 'Content:\n$content';

    switch (action) {
      case 'summarize':
        return '$baseContent\n\nProvide a comprehensive summary with key points and main topics.';
      case 'summary_mindmap':
        return '$baseContent\n\nProvide BOTH a clear summary and a mind map structure with main topics, subtopics, and key points.';
      case 'explain':
        return '$baseContent\n\nExplain in simple, easy-to-understand language with examples and analogies.';
      case 'mindmap':
        return '$baseContent\n\nCreate a mind map structure with main topics, subtopics, and key points using indentation.';
      case 'voice':
        return '$baseContent\n\nCreate a conversational voice note script. Write in a natural, engaging tone with clear sections. Make it sound good when spoken aloud.';
      case 'quiz':
        return _buildQuizPrompt(
          _uploadedFileName ?? 'document',
          _fileContent ?? '',
        );
      case 'all':
        return '$baseContent\n\nProvide ALL of the following:\n1. 📝 Summary\n2. 🧠 Explanation with Examples\n3. 🗺️ Mind Map\n4. 🎧 Voice Note Script\n5. 📚 Flashcards\n\nOrganize each section clearly.';
      default:
        return '$baseContent\n\nProvide a summary.';
    }
  }

  String _getSystemPrompt(String action) {
    switch (action) {
      case 'voice':
        return 'You are a podcast script writer. Create engaging, conversational voice note scripts. Use natural language and clear structure. Write in a style that sounds good when spoken aloud. Keep it warm and friendly.';
      case 'explain':
        return 'You are a patient teacher. Explain complex topics simply with analogies, examples, and step-by-step breakdowns.';
      case 'mindmap':
        return 'You are an expert at organizing information. Create clear hierarchical structures with main topics, subtopics, and key points.';
      case 'summary_mindmap':
        return 'You are an expert educator. Provide both a clear summary and a hierarchical mind map with main topics, subtopics, and key points.';
      case 'quiz':
        return 'You are a quiz generator. You ONLY respond with valid JSON, no extra commentary, no markdown code fences, no explanations before or after. Your entire response must be a single parseable JSON object.';
      default:
        return 'You are NeuroNote AI, a helpful study assistant. The user has provided extracted document text in their message. Use that text directly. Never say you cannot access uploaded files.';
    }
  }

  String _buildQuizPrompt(String sourceLabel, String sourceContent) {
    final content = DocumentTextExtractor.prepareForAi(
      sourceContent,
      maxChars: DocumentTextExtractor.maxQuizSourceChars,
    );
    return 'Based on the following study content from "$sourceLabel", create a multiple-choice practice quiz with exactly 5 questions.\n\n'
        'Content:\n$content\n\n'
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
        'the "correct" value must be copied exactly (character-for-character) from "options", '
        'no markdown formatting, no code fences, no text outside the JSON object.';
  }

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

    final listMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
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

  // ─── Process Uploaded File with AI ──────────────────────────

  Future<void> _processUploadedFile(String action) async {
    if (_fileContent == null ||
        _fileContent!.trim().isEmpty ||
        !DocumentTextExtractor.isUsableContent(_fileContent)) {
      _showErrorSnackBar(
        'Could not read document text. Please upload a readable PDF or TXT file.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _waitingForAction = false;
    });

    String content = _buildFilePrompt(
      action,
      _uploadedFileName ?? 'document',
      _fileContent!,
    );

    try {
      final res = await _callGroqChat(
        action: action,
        systemPrompt: _getSystemPrompt(action),
        userContent: content,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = _extractReply(data);
        if (reply.isNotEmpty) {
          String displayText = '';
          String storageType = '';
          String storageTitle = '';
          String? savedEntryId;

          if (action == 'voice') {
            displayText = '🎧 ${_formatVoiceNote(reply)}';
            storageType = 'audio_note';
            storageTitle = 'Audio Note: ${_uploadedFileName ?? "Document"}';

            String preview = _cleanPreviewForAudio(reply);
            savedEntryId = await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {'sourceFile': _uploadedFileName, 'preview': preview},
            );
            _showInfoSnackBar('✅ Content saved to Audio Notes');
          } else if (action == 'all') {
            displayText = '📚 ${_formatAllResponse(reply)}';
            storageType = 'summary';
            storageTitle = 'Full Analysis: ${_uploadedFileName ?? "Document"}';

            savedEntryId = await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'sourceFile': _uploadedFileName,
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          } else if (action == 'quiz') {
            final quizQuestions = _parseQuizJson(reply);
            storageType = 'quiz';
            storageTitle = 'Quiz: ${_uploadedFileName ?? "Document"}';
            if (quizQuestions.isEmpty) {
              displayText =
                  '⚠️ Could not generate a valid quiz from this document. Please try again.';
            } else {
              displayText =
                  '📝 Practice quiz ready: ${quizQuestions.length} questions on "${_uploadedFileName ?? "Document"}". Open it from Practice Quizzes to start.';

              savedEntryId = await LocalStorageService.saveGeneratedContent(
                type: storageType,
                title: storageTitle,
                content: reply,
                action: action,
                extraData: {
                  'sourceFile': _uploadedFileName,
                  'preview': '${quizQuestions.length} questions',
                  'questions': quizQuestions.length,
                  'quiz_data': quizQuestions,
                },
              );
              _showInfoSnackBar(
                '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
              );
            }
          } else {
            String prefix = '';
            switch (action) {
              case 'summarize':
                prefix = '📝 Summary:\n';
                storageType = 'summary';
                storageTitle = 'Summary: ${_uploadedFileName ?? "Document"}';
                break;
              case 'summary_mindmap':
                prefix = '📝 Summary & 🗺️ Mind Map:\n';
                storageType = 'summary';
                storageTitle =
                    'Summary & Mind Map: ${_uploadedFileName ?? "Document"}';
                break;
              case 'explain':
                prefix = '🧠 Explanation:\n';
                storageType = 'summary';
                storageTitle =
                    'Explanation: ${_uploadedFileName ?? "Document"}';
                break;
              case 'mindmap':
                prefix = '🗺️ Mind Map:\n';
                storageType = 'summary';
                storageTitle = 'Mind Map: ${_uploadedFileName ?? "Document"}';
                break;
              case 'flashcard':
                prefix = '📚 Flashcards:\n';
                storageType = 'flashcard';
                storageTitle = 'Flashcards: ${_uploadedFileName ?? "Document"}';
                break;
              default:
                prefix = '';
                storageType = 'summary';
                storageTitle = 'Content: ${_uploadedFileName ?? "Document"}';
            }
            displayText = prefix + reply;

            savedEntryId = await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'sourceFile': _uploadedFileName,
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          }

          _addMessage(
            displayText,
            false,
            savedEntryId: savedEntryId,
            savedContentType: storageType.isNotEmpty ? storageType : null,
            savedTitle: storageTitle.isNotEmpty ? storageTitle : null,
          );
          if (_shouldAutoGenerateImage(action)) {
            await _maybeGenerateSummaryImage(
              reply,
              action: action,
              storageTitle: storageTitle.isNotEmpty ? storageTitle : null,
            );
          }

          if (action == 'voice' || action == 'all') {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _messages.isNotEmpty) {
                final lastMsg = _messages.last;
                _speakText(lastMsg.text, lastMsg.id);
              }
            });
          }
        } else {
          _addMessage('No response received.', false);
        }
      } else {
        _addMessage(_parseApiError(res), false);
      }
    } catch (e) {
      _addMessage(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isProcessingFile = false;
        });
      }
    }
  }

  String _getStorageTypeLabel(String type) {
    switch (type) {
      case 'flashcard':
        return 'Flashcards';
      case 'quiz':
        return 'Quizzes';
      case 'summary':
        return 'Summaries & Mind Maps';
      case 'audio_note':
        return 'Audio Notes';
      default:
        return 'Content';
    }
  }

  String _buildFilePrompt(String action, String fileName, String fileContent) {
    if (!DocumentTextExtractor.isUsableContent(fileContent)) {
      return 'The uploaded file "$fileName" could not be read as text. '
          'Ask the user to upload a text-based PDF or TXT file.';
    }

    String baseContent =
        'I uploaded a document named "$fileName". '
        'The full extracted text is below — use it directly. '
        'Do not say you cannot access the file.\n\n';
    String content = DocumentTextExtractor.prepareForAi(fileContent);
    baseContent += 'Content:\n$content';

    switch (action) {
      case 'summarize':
        return '$baseContent\n\nProvide a comprehensive summary with key points and main topics.';
      case 'summary_mindmap':
        return '$baseContent\n\nProvide BOTH a clear summary and a mind map structure with main topics, subtopics, and key points.';
      case 'explain':
        return '$baseContent\n\nExplain in simple, easy-to-understand language with examples and analogies.';
      case 'mindmap':
        return '$baseContent\n\nCreate a mind map structure with main topics, subtopics, and key points using indentation.';
      case 'voice':
        return '$baseContent\n\nCreate a conversational voice note script. Write in a natural, engaging tone with clear sections. Make it sound good when spoken aloud.';
      case 'flashcard':
        return '$baseContent\n\nCreate a set of flashcards from this content. Each flashcard should have a question and answer. Format as:\nQ: [question]\nA: [answer]\n\nInclude at least 5-10 flashcards.';
      case 'quiz':
        return _buildQuizPrompt(fileName, fileContent);
      case 'all':
        return '$baseContent\n\nProvide ALL of the following:\n1. 📝 Summary\n2. 🧠 Explanation with Examples\n3. 🗺️ Mind Map\n4. 🎧 Voice Note Script\n5. 📚 Flashcards\n\nOrganize each section clearly.';
      default:
        return '$baseContent\n\nProvide a summary.';
    }
  }

  // ─── Process Initial Action ──────────────────────────────────

  Future<void> _processInitialAction(String action, String content) async {
    if (content.isEmpty) {
      _addMessage(
        'What would you like me to base this on? You can type a topic, paste some text, or upload a document. 🤔',
        false,
      );
      setState(() => _waitingForAction = false);
      return;
    }

    final displayText = content.length > 180
        ? '${content.substring(0, 180)}...'
        : content;
    _addMessage(displayText, true);

    setState(() {
      _loading = true;
    });

    final apiContent = action == 'quiz'
        ? _buildQuizPrompt('content', content)
        : 'Based on this content:\n\n${DocumentTextExtractor.prepareForAi(content)}\n\n'
              '${_actionInstruction(action)}';

    try {
      final res = await _callGroqChat(
        action: action,
        systemPrompt: _getSystemPrompt(action),
        userContent: apiContent,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = _extractReply(data);
        if (reply.isNotEmpty) {
          String prefix = '';
          String storageType = '';
          String storageTitle = '';
          switch (action) {
            case 'summarize':
              prefix = '📝 Summary:\n';
              storageType = 'summary';
              storageTitle = 'Summary';
              break;
            case 'summary_mindmap':
              prefix = '📝 Summary & 🗺️ Mind Map:\n';
              storageType = 'summary';
              storageTitle = 'Summary & Mind Map';
              break;
            case 'explain':
              prefix = '🧠 Explanation:\n';
              storageType = 'summary';
              storageTitle = 'Explanation';
              break;
            case 'mindmap':
              prefix = '🗺️ Mind Map:\n';
              storageType = 'summary';
              storageTitle = 'Mind Map';
              break;
            case 'voice':
              prefix = '🎧 Voice Note:\n';
              storageType = 'audio_note';
              storageTitle = 'Audio Note';
              break;
            case 'flashcard':
              prefix = '📚 Flashcards:\n';
              storageType = 'flashcard';
              storageTitle = 'Flashcards';
              break;
            case 'quiz':
              storageType = 'quiz';
              storageTitle = 'Quiz';
              break;
            case 'all':
              prefix = '📚 Full Analysis:\n';
              storageType = 'summary';
              storageTitle = 'Full Analysis';
              break;
            default:
              prefix = '';
              storageType = 'summary';
              storageTitle = 'Content';
          }

          if (action == 'quiz') {
            final quizQuestions = _parseQuizJson(reply);
            final responseText = quizQuestions.isEmpty
                ? '⚠️ Could not generate a valid quiz from this content. Please try again.'
                : '📝 Practice quiz ready: ${quizQuestions.length} questions. Open it from Practice Quizzes to start.';
            _addMessage(responseText, false);

            if (quizQuestions.isNotEmpty) {
              await LocalStorageService.saveGeneratedContent(
                type: storageType,
                title: storageTitle,
                content: reply,
                action: action,
                extraData: {
                  'preview': '${quizQuestions.length} questions',
                  'questions': quizQuestions.length,
                  'quiz_data': quizQuestions,
                },
              );
              _showInfoSnackBar(
                '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
              );
            }
          } else {
            _addMessage(prefix + reply, false);
            if (_shouldAutoGenerateImage(action)) {
              await _maybeGenerateSummaryImage(
                reply,
                action: action,
                storageTitle: storageTitle,
              );
            }

            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'preview': reply.length > 100
                    ? '${reply.substring(0, 100)}...'
                    : reply,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          }

          if (action == 'voice') {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _messages.isNotEmpty) {
                final lastMsg = _messages.last;
                _speakText(lastMsg.text, lastMsg.id);
              }
            });
          }
        } else {
          _addMessage('No response received.', false);
        }
      } else {
        _addMessage(_parseApiError(res), false);
      }
    } catch (e) {
      _addMessage(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        false,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ─── Follow-up Methods ───────────────────────────────────────

  // void _showFollowUpOptions() {
  //   if (_uploadedFileName != null) {
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       if (mounted) {
  //         _addMessage(
  //           '📄 Would you like me to process "${_uploadedFileName}" further? 🤔',
  //           false,
  //         );
  //         setState(() => _waitingForAction = true);
  //       }
  //     });
  //   } else {
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       if (mounted) {
  //         _addMessage('Would you like to do something else? 🤔', false);
  //         setState(() => _waitingForAction = true);
  //       }
  //     });
  //   }
  // }

  Future<void> _processFollowUp(String action) async {
    if (_uploadedFileName != null && _fileContent != null) {
      await _processUploadedFile(action);
      return;
    }

    setState(() {
      _loading = true;
      _waitingForAction = false;
    });

    String lastContent = '';
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isUser &&
          !_messages[i].text.contains('Would you like')) {
        lastContent = _stripAiDecorations(_messages[i].text);
        break;
      }
    }

    if (lastContent.isEmpty) {
      _addMessage('No content to process.', false);
      setState(() => _loading = false);
      return;
    }

    lastContent = DocumentTextExtractor.prepareForAi(lastContent);

    try {
      final userPromptContent = action == 'quiz'
          ? _buildQuizPrompt('this content', lastContent)
          : action == 'summary_mindmap'
          ? 'Based on this content:\n\n$lastContent\n\nProvide BOTH a clear summary and a mind map structure with main topics, subtopics, and key points. Label each section clearly.'
          : 'Based on this content:\n\n$lastContent\n\nPlease ${action == 'summarize'
                ? 'provide a summary'
                : action == 'explain'
                ? 'explain it in simple terms with examples'
                : action == 'mindmap'
                ? 'create a mind map structure with main topics, subtopics, and key points using indentation'
                : action == 'voice'
                ? 'create a voice note script'
                : action == 'flashcard'
                ? 'create flashcards'
                : 'provide all of the above'}';

      final res = await _callGroqChat(
        action: action,
        systemPrompt: _getSystemPrompt(action),
        userContent: userPromptContent,
      );

      if (res.statusCode == 200) {
        final reply = _extractReply(jsonDecode(res.body));

        String prefix = '';
        String storageType = '';
        String storageTitle = '';

        switch (action) {
          case 'summarize':
            prefix = '📝 Summary:\n';
            storageType = 'summary';
            storageTitle = 'Follow-up Summary';
            break;
          case 'summary_mindmap':
            prefix = '📝 Summary & 🗺️ Mind Map:\n';
            storageType = 'summary';
            storageTitle = 'Follow-up Summary & Mind Map';
            break;
          case 'explain':
            prefix = '🧠 Explanation:\n';
            storageType = 'summary';
            storageTitle = 'Follow-up Explanation';
            break;
          case 'mindmap':
            prefix = '🗺️ Mind Map:\n';
            storageType = 'summary';
            storageTitle = 'Follow-up Mind Map';
            break;
          case 'voice':
            prefix = '🎧 Voice Note:\n';
            storageType = 'audio_note';
            storageTitle = 'Follow-up Audio Note';
            break;
          case 'flashcard':
            prefix = '📚 Flashcards:\n';
            storageType = 'flashcard';
            storageTitle = 'Follow-up Flashcards';
            break;
          case 'quiz':
            storageType = 'quiz';
            storageTitle = 'Follow-up Quiz';
            break;
          case 'all':
            prefix = '📚 Full Analysis:\n';
            storageType = 'summary';
            storageTitle = 'Follow-up Full Analysis';
            break;
          default:
            prefix = '';
            storageType = 'summary';
            storageTitle = 'Follow-up Content';
        }

        if (action == 'quiz') {
          final quizQuestions = _parseQuizJson(reply);
          final responseText = quizQuestions.isEmpty
              ? '⚠️ Could not generate a valid quiz from this content. Please try again.'
              : '📝 Practice quiz ready: ${quizQuestions.length} questions. Open it from Practice Quizzes to start.';
          _addMessage(responseText, false);

          if (quizQuestions.isNotEmpty) {
            await LocalStorageService.saveGeneratedContent(
              type: storageType,
              title: storageTitle,
              content: reply,
              action: action,
              extraData: {
                'source': 'Follow-up',
                'preview': '${quizQuestions.length} questions',
                'questions': quizQuestions.length,
                'quiz_data': quizQuestions,
              },
            );
            _showInfoSnackBar(
              '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
            );
          }
        } else {
          final responseText =
              prefix + (reply.isNotEmpty ? reply : 'No response.');
          _addMessage(responseText, false);
          if (_shouldAutoGenerateImage(action) && reply.isNotEmpty) {
            await _maybeGenerateSummaryImage(
              reply,
              action: action,
              storageTitle: storageTitle,
            );
          }

          await LocalStorageService.saveGeneratedContent(
            type: storageType,
            title: storageTitle,
            content: reply,
            action: action,
            extraData: {
              'source': 'Follow-up',
              'preview': reply.length > 100
                  ? '${reply.substring(0, 100)}...'
                  : reply,
            },
          );
          _showInfoSnackBar(
            '✅ Content saved to ${_getStorageTypeLabel(storageType)}',
          );
        }

        if (action == 'voice' || action == 'all') {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && _messages.isNotEmpty) {
              final lastMsg = _messages.last;
              _speakText(lastMsg.text, lastMsg.id);
            }
          });
        }
      } else {
        _addMessage('Error processing request.', false);
      }
    } catch (e) {
      _addMessage(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Chat Methods ────────────────────────────────────────────

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeKey = await AuthService.scopedKey(_historyKey);
      await prefs.setString(
        activeKey,
        jsonEncode(_messages.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    });
  }

  void _addMessage(
    String text,
    bool isUser, {
    String? imageBase64,
    String? imageMimeType,
    String? imageUrl,
    String? retrySummaryText,
    String? savedEntryId,
    String? savedContentType,
    String? savedTitle,
    bool isFavorited = false,
  }) {
    final message = ChatMessage(
      text: text,
      isUser: isUser,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
      imageUrl: imageUrl,
      retrySummaryText: retrySummaryText,
      savedEntryId: savedEntryId,
      savedContentType: savedContentType,
      savedTitle: savedTitle,
      isFavorited: isFavorited,
    );
    setState(() => _messages.add(message));
    _saveHistory();
    _scrollDown();
  }

  Future<void> _toggleMessageFavorite(ChatMessage message) async {
    if (message.savedEntryId == null || message.savedContentType == null) {
      return;
    }
    final favType = message.savedContentType == 'audio_note'
        ? 'audio'
        : message.savedContentType!;
    final item = {
      'title': message.savedTitle ?? 'Content',
      'type': favType,
      'data': {'id': message.savedEntryId},
    };
    final newStatus = await SavedService.toggleFavorite(item);
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(isFavorited: newStatus);
      }
    });
    _showInfoSnackBar(
      newStatus ? '❤️ Added to favorites' : 'Removed from favorites',
    );
  }

  Future<void> _deleteMessageContent(ChatMessage message) async {
    if (message.savedEntryId == null || message.savedContentType == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this content?'),
        content: const Text('This will remove it from saved materials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await LocalStorageService.deleteContentById(
      message.savedContentType!,
      message.savedEntryId!,
    );
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    _saveHistory();
    _showInfoSnackBar('Content deleted');
  }

  // ─── Image Generation Methods ─────────────────────────────────

  bool _shouldAutoGenerateImage(String action) {
    return action == 'summarize' ||
        action == 'summary_mindmap' ||
        action == 'mindmap';
  }

  bool _shouldAutoGenerateImageFromText(String text) {
    final lower = text.toLowerCase();
    return lower.contains('summar') ||
        lower.contains('mind map') ||
        lower.contains('mindmap');
  }

  String _buildSummaryImagePrompt(String summaryText, {String? action}) {
    final topic = _extractImageTopic(summaryText);
    final keywords = _extractImageKeywords(summaryText);
    final keywordPart = keywords.isNotEmpty
        ? ' Key elements to depict: $keywords.'
        : '';

    if (action == 'summary_mindmap' || action == 'mindmap') {
      return 'A clean, simple educational mind map diagram about "$topic". '
          'One central bubble in the middle connected by lines to 4-6 branch '
          'bubbles.$keywordPart '
          'Flat vector infographic, bright solid colors, thick clean lines, '
          'large simple icons, minimal short labels only, lots of white space, '
          'no paragraphs, no gibberish text, no watermark. Sharp, high detail.';
    }

    return 'A clean, simple educational infographic illustration about '
        '"$topic".$keywordPart '
        'Flat vector style, bright solid colors, large clear icons and simple '
        'diagrams, minimal short labels only, lots of white space, '
        'no paragraphs, no gibberish text, no watermark. Sharp, high detail.';
  }

  String _extractImageTopic(String summaryText) {
    final firstLine = summaryText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => 'Study Notes');
    var topic = firstLine
        .replaceAll(RegExp(r'^[^\w]+'), '')
        .replaceAll(
          RegExp(r'^(Summary|Topic|Title)\s*:\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[#*_>`]'), '')
        .trim();
    if (topic.length > 80) topic = '${topic.substring(0, 80)}...';
    return topic.isEmpty ? 'Study Notes' : topic;
  }

  String _extractImageKeywords(String summaryText) {
    final stop = {
      'the',
      'and',
      'for',
      'are',
      'but',
      'not',
      'you',
      'with',
      'this',
      'that',
      'from',
      'they',
      'have',
      'has',
      'was',
      'were',
      'will',
      'can',
      'a',
      'an',
      'of',
      'to',
      'in',
      'on',
      'is',
      'it',
      'as',
      'by',
      'or',
      'summary',
      'topic',
      'note',
      'notes',
    };
    final words = RegExp(r'[A-Za-z][A-Za-z-]{3,}')
        .allMatches(summaryText)
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => !stop.contains(w))
        .toList();

    final counts = <String, int>{};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(6).join(', ');
  }

  Future<String?> _downloadPollinationsImage(String prompt) async {
    final url = _pollinationsImageUrl(prompt);
    final candidates = <String>[
      url,
      if (kIsWeb) 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      if (kIsWeb)
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
      if (kIsWeb)
        'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}',
    ];

    for (final candidate in candidates) {
      try {
        final res = await http
            .get(Uri.parse(candidate))
            .timeout(const Duration(seconds: 90));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return base64Encode(res.bodyBytes);
        }
      } catch (_) {}
    }
    return null;
  }

  String _networkImageUrl(String url) {
    if (!kIsWeb) return url;
    if (url.contains('pollinations.ai') || url.contains('generativelanguage')) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  String _pollinationsImageUrl(String prompt) {
    final shortPrompt = prompt.length > 400
        ? '${prompt.substring(0, 400)}...'
        : prompt;
    final seed = DateTime.now().millisecondsSinceEpoch;
    return 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(shortPrompt)}'
        '?width=1024&height=1024&nologo=true&enhance=true&model=flux&seed=$seed';
  }

  List<String> _geminiRequestUrls(String model, bool useV1Beta) {
    final apiVersion = useV1Beta ? 'v1beta' : 'v1';
    final directUrl =
        'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=${Uri.encodeQueryComponent(_geminiApiKey)}';

    if (!kIsWeb) return [directUrl];

    return [
      directUrl,
      'https://corsproxy.io/?${Uri.encodeComponent(directUrl)}',
      'https://cors.bridged.cc/$directUrl',
    ];
  }

  String? _extractGeminiImageBase64(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List) return null;

    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final part in parts) {
        if (part is! Map) continue;
        final inlineData = part['inlineData'] ?? part['inline_data'];
        if (inlineData is! Map) continue;
        final data = inlineData['data']?.toString();
        if (data != null && data.isNotEmpty) return data;
      }
    }
    return null;
  }

  String? _extractGeminiImageMimeType(
    Map<String, dynamic> body, {
    String fallback = 'image/png',
  }) {
    final candidates = body['candidates'];
    if (candidates is! List) return fallback;

    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final part in parts) {
        if (part is! Map) continue;
        final inlineData = part['inlineData'] ?? part['inline_data'];
        if (inlineData is! Map) continue;
        final mimeType = inlineData['mimeType'] ?? inlineData['mime_type'];
        if (mimeType != null && mimeType.toString().isNotEmpty) {
          return mimeType.toString();
        }
      }
    }
    return fallback;
  }

  Future<http.Response?> _requestGeminiSummaryImage(String prompt) async {
    final payloads = [
      jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['TEXT', 'IMAGE'],
        },
      }),
      jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    ];

    for (final model in _geminiImageModels) {
      for (final useV1Beta in [false, true]) {
        for (final endpoint in _geminiRequestUrls(model, useV1Beta)) {
          for (final payload in payloads) {
            try {
              final res = await http
                  .post(
                    Uri.parse(endpoint),
                    headers: const {'Content-Type': 'application/json'},
                    body: payload,
                  )
                  .timeout(const Duration(seconds: 90));

              if (res.statusCode == 200) return res;
            } catch (_) {
              continue;
            }
          }
        }
      }
    }
    return null;
  }

  Future<(String?, String?, String?)?> _generateSummaryImageData(
    String summaryText, {
    String? action,
  }) async {
    final prompt = _buildSummaryImagePrompt(summaryText, action: action);
    if (prompt.trim().isEmpty) return null;

    try {
      String? imageBase64;
      String? imageMimeType;
      String? imageUrl;

      final res = await _requestGeminiSummaryImage(prompt);
      if (res != null) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) {
          imageBase64 = _extractGeminiImageBase64(body);
          imageMimeType = _extractGeminiImageMimeType(body);
        }
      }

      imageBase64 ??= await _downloadPollinationsImage(prompt);
      imageMimeType ??= 'image/jpeg';

      if (imageBase64 != null) {
        return (imageBase64, imageMimeType, null);
      }

      imageUrl = _pollinationsImageUrl(prompt);
      final retryBase64 = await _downloadPollinationsImage(prompt);
      if (retryBase64 != null) {
        return (retryBase64, 'image/jpeg', null);
      }

      return (null, null, imageUrl);
    } catch (_) {
      final fallbackUrl = _pollinationsImageUrl(prompt);
      final fallbackBase64 = await _downloadPollinationsImage(prompt);
      if (fallbackBase64 != null) {
        return (fallbackBase64, 'image/jpeg', null);
      }
      return (null, null, fallbackUrl);
    }
  }

  Future<void> _maybeGenerateSummaryImage(
    String summaryText, {
    String? action,
    String? storageTitle,
  }) async {
    final imageData = await _generateSummaryImageData(
      summaryText,
      action: action,
    );
    if (imageData != null && (imageData.$1 != null || imageData.$3 != null)) {
      if (storageTitle != null) {
        await LocalStorageService.attachImageToLatestSummary(
          title: storageTitle,
          imageBase64: imageData.$1,
          imageMimeType: imageData.$2,
          imageUrl: imageData.$3,
        );
      }
      _addMessage(
        action == 'summary_mindmap' || action == 'mindmap'
            ? '🖼️ Visual mind map'
            : '🖼️ Visual summary',
        false,
        imageBase64: imageData.$1,
        imageMimeType: imageData.$2,
        imageUrl:
            imageData.$3 ??
            _pollinationsImageUrl(
              _buildSummaryImagePrompt(summaryText, action: action),
            ),
        retrySummaryText: summaryText,
      );
      return;
    }

    _addMessage(
      '🖼️ Summary image generate nahi ho rahi. Retry karein?',
      false,
      retrySummaryText: summaryText,
    );
  }

  // ─── API Helper Methods ──────────────────────────────────────

  int _groqMaxTokens(String action) {
    if (action == 'quiz') return 4096;
    if (action == 'all' ||
        action == 'summary_mindmap' ||
        action == 'mindmap' ||
        action == 'flashcard') {
      return 2048;
    }
    return 1536;
  }

  double _groqTemperature(String action) => action == 'quiz' ? 0.3 : 0.5;

  String _actionInstruction(String action) {
    switch (action) {
      case 'summarize':
        return 'Provide a comprehensive summary with key points and main topics.';
      case 'summary_mindmap':
        return 'Provide BOTH a clear summary and a mind map structure with main topics, subtopics, and key points.';
      case 'explain':
        return 'Explain in simple, easy-to-understand language with examples and analogies.';
      case 'mindmap':
        return 'Create a mind map structure with main topics, subtopics, and key points using indentation.';
      case 'voice':
        return 'Create a conversational voice note script in a natural, engaging tone.';
      case 'flashcard':
        return 'Create flashcards with Q: and A: format. Include at least 5-10 flashcards.';
      case 'all':
        return 'Provide ALL: Summary, Explanation, Mind Map, Voice Note Script, and Flashcards.';
      default:
        return 'Provide a helpful summary.';
    }
  }

  Future<http.Response> _callGroqChat({
    required String action,
    required String systemPrompt,
    required String userContent,
  }) async {
    var prompt = userContent;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt == 1) {
        prompt = DocumentTextExtractor.prepareForAi(
          prompt,
          maxChars: DocumentTextExtractor.maxQuizSourceChars,
        );
      }

      final res = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _groqModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt},
              ],
              'temperature': _groqTemperature(action),
              'max_tokens': _groqMaxTokens(action),
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) return res;

      final err = _parseApiError(res).toLowerCase();
      final isTokenLimit =
          err.contains('too large') ||
          err.contains('tpm') ||
          err.contains('token');
      if (!isTokenLimit || attempt == 1) return res;
    }

    throw Exception('Groq request failed');
  }

  String _extractReply(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    final message = first['message'];
    return message?['content']?.toString().trim() ?? '';
  }

  String _stripAiDecorations(String text) {
    return text
        .replaceAll(RegExp(r'[📝🧠🗺️🎧📚🖼️🔹🔸▶️]'), '')
        .replaceAll(
          RegExp(
            r'^(Summary|Mind Map|Explanation|Voice Note)[:\s]*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _parseApiError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map) {
          final message = error['message']?.toString();
          if (message != null && message.isNotEmpty) {
            final lower = message.toLowerCase();
            if (lower.contains('too large') ||
                lower.contains('tpm') ||
                lower.contains('tokens per minute')) {
              return '⚠️ Document is too large for AI. Please try a shorter PDF or TXT file.';
            }
            return 'Error: $message';
          }
        }
      }
    } catch (_) {}
    return 'Error: ${res.statusCode}';
  }

  String _imageMimeType(XFile image) {
    final name = image.name.toLowerCase();
    final path = image.path.toLowerCase();
    if (name.endsWith('.png') || path.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp') || path.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif') || path.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<({Uint8List bytes, String mimeType})> _prepareImageForGroq(
    Uint8List bytes,
  ) async {
    if (bytes.length <= _maxVisionImageBytes) {
      return (bytes: bytes, mimeType: 'image/jpeg');
    }

    for (final width in [1280, 1024, 800, 640, 480]) {
      final resized = await _resizeImageBytes(bytes, maxWidth: width);
      if (resized != null && resized.length <= _maxVisionImageBytes) {
        return (bytes: resized, mimeType: 'image/png');
      }
    }

    throw Exception(
      'Image is too large. Please capture a smaller photo and try again.',
    );
  }

  Future<Uint8List?> _resizeImageBytes(
    Uint8List bytes, {
    required int maxWidth,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ─── Send Message ─────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    if (_waitingForAction) {
      final action = text.toLowerCase();
      if (action.contains('summarize') || action.contains('summary')) {
        await _processFollowUp('summarize');
        _input.clear();
        return;
      }
      if (action.contains('explain')) {
        await _processFollowUp('explain');
        _input.clear();
        return;
      }
      if (action.contains('mind map') || action.contains('mindmap')) {
        await _processFollowUp('mindmap');
        _input.clear();
        return;
      }
      if (action.contains('voice') || action.contains('audio')) {
        await _processFollowUp('voice');
        _input.clear();
        return;
      }
      if (action.contains('flashcard') || action.contains('flash cards')) {
        await _processFollowUp('flashcard');
        _input.clear();
        return;
      }
      if (action.contains('quiz')) {
        await _processFollowUp('quiz');
        _input.clear();
        return;
      }
      if (action.contains('all') || action.contains('everything')) {
        await _processFollowUp('all');
        _input.clear();
        return;
      }
      if (action.contains('no') || action.contains('nothing')) {
        setState(() => _waitingForAction = false);
        _addMessage('Alright! 😊', false);
        _input.clear();
        return;
      }
    }

    if (_selectedFile != null) {
      _showFilePreview('Processing $_uploadedFileName');
      _input.clear();
      return;
    }

    _addMessage(text, true);
    _input.clear();
    setState(() => _loading = true);

    final hasDocument =
        _fileContent != null &&
        DocumentTextExtractor.isUsableContent(_fileContent!);

    final systemPrompt = hasDocument
        ? 'You are NeuroNote AI - a friendly study assistant. '
              'The user has uploaded a document. Its full text content is '
              'provided below. Use ONLY this content to answer, generate '
              'questions, summaries, flashcards, or explanations. Never say '
              'you cannot access or read the document — the text is right here.'
              '\n\n--- DOCUMENT CONTENT START ---\n'
              '${DocumentTextExtractor.prepareForAi(_fileContent!)}'
              '\n--- DOCUMENT CONTENT END ---'
        : 'You are NeuroNote AI - a friendly study assistant.';

    try {
      final res = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _groqModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                ..._messages
                    .where((m) => !m.text.startsWith('📄 Uploaded:'))
                    .map(
                      (m) => {
                        'role': m.isUser ? 'user' : 'assistant',
                        'content': m.text,
                      },
                    ),
              ],
              'temperature': 0.7,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final reply = _extractReply(jsonDecode(res.body));
        _addMessage(reply.isNotEmpty ? reply : 'No response.', false);
        if (_shouldAutoGenerateImageFromText(text) && reply.isNotEmpty) {
          await _maybeGenerateSummaryImage(
            reply,
            action:
                text.toLowerCase().contains('mind map') ||
                    text.toLowerCase().contains('mindmap')
                ? 'summary_mindmap'
                : 'summarize',
          );
        }
      } else {
        _addMessage(_parseApiError(res), false);
      }
    } catch (e) {
      _addMessage(e.toString().replaceFirst('Exception: ', ''), false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Helper Methods ───────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Chat?',
          style: GoogleFonts.poppins(color: Colors.teal),
        ),
        content: Text(
          'All messages will be deleted.',
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
              setState(() => _messages.clear());
              await _saveHistory();
              Navigator.pop(c);
              _showInfoSnackBar('Chat cleared');
            },
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _saveAndGoBack() async {
    if (_messages.isNotEmpty) {
      await _saveCurrentChat();
    }
    if (!mounted) return;
    if (widget.returnToUploadOnBack) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  Widget _buildSuggestionChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: Colors.teal.shade700),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onPressed: () {
        _input.text = label;
        _sendMessage();
      },
      backgroundColor: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal.shade200),
      ),
    );
  }

  Widget _buildFollowUpChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.teal.shade100,
      labelStyle: TextStyle(
        color: Colors.teal.shade800,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal.shade300),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saveAndGoBack,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.teal,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NeuroNote AI',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.shade400.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'BETA',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Powered by Groq Llama 3.3',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: _showHistoryDrawer,
            tooltip: 'Chat History',
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          if (_currentlyPlayingId != null)
            IconButton(
              tooltip: 'Stop Voice',
              onPressed: _stopAudio,
              icon: const Icon(Icons.stop_circle, color: Colors.white),
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
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 50,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '🧠 NeuroNote AI',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a document, take a photo, or ask a question!',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.upload_file,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Upload a document or take a photo!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[_messages.length - 1 - i];
                          return _MessageBubble(
                            message: m,
                            isPlaying: _currentlyPlayingId == m.id,
                            onPlay: !m.isUser && m.text.length > 30
                                ? () => _speakText(m.text, m.id)
                                : null,
                            onCopy: !m.isUser
                                ? () => _copyToClipboard(m.text)
                                : null,
                            onRetryImage:
                                (!m.isUser && m.retrySummaryText != null)
                                ? () => _maybeGenerateSummaryImage(
                                    m.retrySummaryText!,
                                  )
                                : null,
                            onFavorite: (!m.isUser && m.savedEntryId != null)
                                ? () => _toggleMessageFavorite(m)
                                : null,
                            onDelete: (!m.isUser && m.savedEntryId != null)
                                ? () => _deleteMessageContent(m)
                                : null,
                          );
                        },
                      ),
              ),
              if (_waitingForAction)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFollowUpChip(
                        '📝 Summary & Mind Map',
                        () => _processFollowUp('summary_mindmap'),
                      ),
                      _buildFollowUpChip(
                        '🧠 Explain',
                        () => _processFollowUp('explain'),
                      ),
                      _buildFollowUpChip(
                        '🎧 Voice Note',
                        () => _processFollowUp('voice'),
                      ),
                      _buildFollowUpChip(
                        '📚 Flashcards',
                        () => _processFollowUp('flashcard'),
                      ),
                      _buildFollowUpChip(
                        '📝 Practice Quiz',
                        () => _processFollowUp('quiz'),
                      ),
                      _buildFollowUpChip(
                        '📚 All',
                        () => _processFollowUp('all'),
                      ),
                      _buildFollowUpChip('❌ No', () {
                        setState(() => _waitingForAction = false);
                        _addMessage('Alright! 😊', false);
                      }),
                    ],
                  ),
                ),
              if (_messages.isNotEmpty || _uploadedFileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _captureImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Camera',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _pickDocument,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.upload_file,
                                size: 16,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Upload',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_uploadedFileName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _uploadedFileName!.length > 15
                                    ? '${_uploadedFileName!.substring(0, 15)}...'
                                    : _uploadedFileName!,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              InkWell(
                                onTap: _clearUploadedFile,
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_capturedImage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.image,
                                size: 12,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '📸 Image',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              InkWell(
                                onTap: _clearCapturedImage,
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (_loading)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isProcessingFile || _isProcessingImage
                            ? 'Processing… 📄'
                            : 'Thinking… 🤔',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _captureImage,
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.teal,
                        size: 24,
                      ),
                      tooltip: 'Take Photo',
                    ),
                    if (_uploadedFileName == null && _capturedImage == null)
                      IconButton(
                        onPressed: _pickDocument,
                        icon: const Icon(
                          Icons.upload_file,
                          color: Colors.teal,
                          size: 24,
                        ),
                        tooltip: 'Upload Document',
                      ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !_loading,
                        style: GoogleFonts.poppins(color: Colors.grey.shade800),
                        decoration: InputDecoration(
                          hintText: _uploadedFileName != null
                              ? 'Choose an action for your document…'
                              : _capturedImage != null
                              ? 'Choose an action for your image…'
                              : _waitingForAction
                              ? 'Type summarize, explain, mind map, voice, flashcards, quiz, all, or no…'
                              : 'Type your question, upload, or take a photo…',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _sendMessage,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _loading
                              ? Icons.hourglass_top_rounded
                              : Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Chat Message Model ────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String id;
  final String? imageBase64;
  final String? imageMimeType;
  final String? imageUrl;
  final String? retrySummaryText;
  final String? savedEntryId;
  final String? savedContentType;
  final String? savedTitle;
  final bool isFavorited;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBase64,
    this.imageMimeType,
    this.imageUrl,
    this.retrySummaryText,
    this.savedEntryId,
    this.savedContentType,
    this.savedTitle,
    this.isFavorited = false,
  }) : timestamp = DateTime.now(),
       id = DateTime.now().millisecondsSinceEpoch.toString();

  ChatMessage._({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.id,
    this.imageBase64,
    this.imageMimeType,
    this.imageUrl,
    this.retrySummaryText,
    this.savedEntryId,
    this.savedContentType,
    this.savedTitle,
    this.isFavorited = false,
  });

  ChatMessage copyWith({bool? isFavorited}) => ChatMessage._(
    text: text,
    isUser: isUser,
    timestamp: timestamp,
    id: id,
    imageBase64: imageBase64,
    imageMimeType: imageMimeType,
    imageUrl: imageUrl,
    retrySummaryText: retrySummaryText,
    savedEntryId: savedEntryId,
    savedContentType: savedContentType,
    savedTitle: savedTitle,
    isFavorited: isFavorited ?? this.isFavorited,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'imageBase64': imageBase64,
    'imageMimeType': imageMimeType,
    'imageUrl': imageUrl,
    'retrySummaryText': retrySummaryText,
    'savedEntryId': savedEntryId,
    'savedContentType': savedContentType,
    'savedTitle': savedTitle,
    'isFavorited': isFavorited,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage._(
    id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    text: j['text']?.toString() ?? '',
    isUser: j['isUser'] == true,
    timestamp:
        DateTime.tryParse(j['timestamp']?.toString() ?? '') ?? DateTime.now(),
    imageBase64: j['imageBase64']?.toString(),
    imageMimeType: j['imageMimeType']?.toString(),
    imageUrl: j['imageUrl']?.toString(),
    retrySummaryText: j['retrySummaryText']?.toString(),
    savedEntryId: j['savedEntryId']?.toString(),
    savedContentType: j['savedContentType']?.toString(),
    savedTitle: j['savedTitle']?.toString(),
    isFavorited: j['isFavorited'] == true,
  );
}

// ─── Message Bubble Widget ─────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isPlaying;
  final VoidCallback? onPlay;
  final VoidCallback? onCopy;
  final VoidCallback? onRetryImage;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    this.isPlaying = false,
    this.onPlay,
    this.onCopy,
    this.onRetryImage,
    this.onFavorite,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF006D77), Color(0xFF83C5BE)],
                )
              : const LinearGradient(colors: [Colors.white, Color(0xFFF5F5F5)]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageBase64 != null ||
                message.imageUrl != null ||
                message.retrySummaryText != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildImageWidget(maxWidth),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 10),
            ],
            if (message.text.isNotEmpty) ...[
              Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: isUser ? Colors.white : Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!isUser &&
                message.retrySummaryText != null &&
                onRetryImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ActionChip(
                  avatar: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.teal,
                  ),
                  label: Text(
                    'Retry image',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: onRetryImage,
                  backgroundColor: Colors.teal.shade50,
                  side: BorderSide(color: Colors.teal.shade200),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isUser
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                if (!isUser && onCopy != null && message.text.isNotEmpty) ...[
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isUser && onPlay != null && message.text.isNotEmpty) ...[
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPlaying ? Colors.green : Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 14,
                            color: isPlaying ? Colors.green : Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPlaying ? 'Playing' : 'Listen',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: isPlaying ? Colors.green : Colors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!isUser && onFavorite != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onFavorite,
                    child: Icon(
                      message.isFavorited
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 18,
                      color: message.isFavorited ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
                if (!isUser && onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(double maxWidth) {
    if (message.imageBase64 != null) {
      try {
        return Image.memory(
          base64Decode(message.imageBase64!),
          fit: BoxFit.cover,
          width: maxWidth,
          height: 200,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage(maxWidth);
          },
        );
      } catch (e) {
        return _buildPlaceholderImage(maxWidth);
      }
    }

    if (message.imageUrl != null) {
      return Image.network(
        _networkImageUrl(message.imageUrl!),
        fit: BoxFit.cover,
        width: maxWidth,
        height: 200,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: maxWidth,
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(maxWidth);
        },
      );
    }

    if (message.retrySummaryText != null) {
      return _buildPlaceholderImage(maxWidth);
    }

    return const SizedBox.shrink();
  }

  String _networkImageUrl(String url) {
    if (!kIsWeb) return url;
    if (url.contains('pollinations.ai') || url.contains('generativelanguage')) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  Widget _buildPlaceholderImage(double maxWidth) {
    return Container(
      width: maxWidth,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.teal.shade300),
            const SizedBox(height: 8),
            Text(
              message.retrySummaryText != null
                  ? 'Tap Retry image below'
                  : 'Image loading...',
              style: TextStyle(color: Colors.teal.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
