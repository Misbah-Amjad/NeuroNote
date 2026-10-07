import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:neuronote/task.dart';

import 'dashboard.dart';
import 'editprofile.dart';
import 'flashcard.dart';
import 'forgotpassword.dart';
import 'landingpage.dart';
import 'learning_hub.dart';
import 'login.dart';
import 'navigation.dart';
import 'notification.dart';
import 'practice_quiz.dart';
import 'profile_setup.dart';
import 'save.dart';
import 'signup.dart';
import 'splash.dart';
import 'theme.dart';
import 'upload_content.dart';
import 'userprofile.dart';
import 'walkthroughscreens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(DevicePreview(enabled: true, builder: (context) => const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroNote',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.tealTheme,
      initialRoute: '/splash',
      routes: appRoutes,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}

final Map<String, WidgetBuilder> appRoutes = {
  '/splash': (context) => SplashScreen(),
  '/task': (context) => Task(),
  '/landing': (context) => LandingScreen(),
  '/login': (context) => LoginScreen(),
  '/signup': (context) => SignupScreen(),
  '/forgotpassword': (context) => ForgotPasswordScreen(),
  '/walkthrough': (context) => WalkthroughScreen(),
  '/navigation': (context) => MainNavigation(),
  '/profilesetup': (context) => ProfileSetupFlow(),
  '/dashboard': (context) => DashboardScreen(),
  '/profile': (context) => ProfileScreen(),
  '/notification': (context) => NotificationScreen(),
  '/saved': (context) => SavedScreen(),
  '/learning': (context) => LearningHubScreen(),
  '/uploadcontent': (context) => UploadContentScreen(),
  '/editprofile': (context) => EditProfileScreen(),
  '/flashcard': (context) => FlashcardsScreen(),
  '/practice': (context) => PracticeQuizScreen(),
};

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Mimi - AI Chat',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.pink,
//         primaryColor: const Color(0xFFFFB7C5),
//         scaffoldBackgroundColor: const Color(0xFFFFF0F3),
//         fontFamily: 'Poppins',
//         appBarTheme: const AppBarTheme(
//           backgroundColor: Color(0xFFFFB7C5),
//           foregroundColor: Color(0xFF8B5E6B),
//           elevation: 0,
//           centerTitle: true,
//         ),
//         inputDecorationTheme: InputDecorationTheme(
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 20,
//             vertical: 16,
//           ),
//         ),
//       ),
//       home: const ChatScreen(),
//     );
//   }
// }

// class ChatScreen extends StatefulWidget {
//   const ChatScreen({super.key});

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final List<ChatMessage> _messages = [];
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   bool _isLoading = false;
//   bool _isListening = false;
//   bool _neuralVoice = true;

//   // API Endpoints
//   final String _chatEndpoint = 'http://72.62.246.243:8091/api/chat';
//   final String _chatAudioEndpoint = 'http://72.62.246.243:8091/api/chat-audio';

//   @override
//   void initState() {
//     super.initState();
//     _initSpeech();
//     _loadChatHistory();
//   }

//   Future<void> _initSpeech() async {
//     await _speech.initialize();
//   }

//   Future<void> _loadChatHistory() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? saved = prefs.getString('chat_history');
//       if (saved != null) {
//         final List<dynamic> decoded = jsonDecode(saved);
//         setState(() {
//           _messages.clear();
//           _messages.addAll(
//             decoded.map((e) => ChatMessage.fromJson(e)).toList(),
//           );
//         });
//       }
//     } catch (e) {
//       print('Error loading chat history: $e');
//     }
//   }

//   Future<void> _saveChatHistory() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String encoded = jsonEncode(
//         _messages.map((e) => e.toJson()).toList(),
//       );
//       await prefs.setString('chat_history', encoded);
//     } catch (e) {
//       print('Error saving chat history: $e');
//     }
//   }

//   void _addMessage(String text, bool isUser, {String? audioBase64}) {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: text,
//           isUser: isUser,
//           timestamp: DateTime.now(),
//           audioBase64: audioBase64,
//         ),
//       );
//     });
//     _saveChatHistory();
//   }

//   Future<void> _sendMessage({String? audioPath}) async {
//     if ((_messageController.text.isEmpty || _isLoading) && audioPath == null) {
//       return;
//     }

//     final userMessage = audioPath != null
//         ? '🎤 [Voice Message]'
//         : _messageController.text.trim();
//     if (userMessage.isEmpty) return;

//     // Add user message
//     _addMessage(userMessage, true);
//     _messageController.clear();
//     setState(() => _isLoading = true);

//     try {
//       http.Response response;

//       if (audioPath != null) {
//         // Send audio message
//         final request = http.MultipartRequest(
//           'POST',
//           Uri.parse(_chatAudioEndpoint),
//         );
//         request.headers['Authorization'] = 'Bearer $_apiKey';
//         request.files.add(
//           await http.MultipartFile.fromPath('audio', audioPath),
//         );
//         request.fields['neural_voice'] = _neuralVoice.toString();
//         final streamedResponse = await request.send();
//         response = await http.Response.fromStream(streamedResponse);
//       } else {
//         // Send text message
//         response = await http
//             .post(
//               Uri.parse(_chatEndpoint),
//               headers: {
//                 'Authorization': 'Bearer $_apiKey',
//                 'Content-Type': 'application/json',
//               },
//               body: jsonEncode({
//                 'message': userMessage,
//                 'neural_voice': _neuralVoice,
//               }),
//             )
//             .timeout(const Duration(seconds: 30));
//       }

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         String aiResponse =
//             data['response'] ?? data['reply'] ?? 'I understand. Tell me more.';
//         String? audioBase64 =
//             data['audio_mp3_base64'] ?? data['audio_base64'] ?? data['audio'];

//         _addMessage(aiResponse, false, audioBase64: audioBase64);

//         if (_neuralVoice && audioBase64 != null && audioBase64.isNotEmpty) {
//           await _playAudioFromBase64(audioBase64);
//         }
//       } else {
//         _addMessage(
//           'Sorry, I\'m having trouble connecting. Please try again.',
//           false,
//         );
//         print('API Error: ${response.statusCode} - ${response.body}');
//       }
//     } catch (e) {
//       _addMessage('Error: ${e.toString().replaceAll('Exception:', '')}', false);
//       print('Error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _startVoiceInput() async {
//     bool available = await _speech.initialize();
//     if (available) {
//       setState(() => _isListening = true);
//       _speech.listen(
//         onResult: (result) {
//           setState(() {
//             _messageController.text = result.recognizedWords;
//             _isListening = false;
//           });
//           if (result.finalResult) {
//             _sendMessage();
//           }
//         },
//         listenMode: stt.ListenMode.dictation,
//       );
//     } else {
//       _showSnackBar('Speech recognition not available', Colors.red);
//     }
//   }

//   Future<void> _playAudioFromBase64(String base64Audio) async {
//     try {
//       final bytes = base64Decode(base64Audio);
//       final tempDir = await Directory.systemTemp.createTemp();
//       final file = File(
//         '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
//       );
//       await file.writeAsBytes(bytes);
//       await _audioPlayer.play(DeviceFileSource(file.path));

//       // Clean up after playing
//       Future.delayed(const Duration(seconds: 10), () {
//         file.delete();
//         tempDir.delete();
//       });
//     } catch (e) {
//       print('Audio playback error: $e');
//       _showSnackBar('Could not play audio', Colors.orange);
//     }
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   void _clearChat() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//         title: const Text('Clear Chat'),
//         content: const Text('Are you sure you want to clear all messages?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text(
//               'Cancel',
//               style: TextStyle(color: Color(0xFFD4A5B3)),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               setState(() => _messages.clear());
//               await _saveChatHistory();
//               Navigator.pop(context);
//               _showSnackBar('Chat cleared', Colors.green);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: const Text('Clear', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Chat with Mimi',
//           style: TextStyle(
//             color: Color(0xFF8B5E6B),
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         backgroundColor: const Color(0xFFFFB7C5),
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.delete_outline, color: Color(0xFF8B5E6B)),
//             onPressed: _messages.isEmpty ? null : _clearChat,
//           ),
//           IconButton(
//             icon: const Icon(Icons.volume_up, color: Color(0xFF8B5E6B)),
//             onPressed: () {
//               setState(() => _neuralVoice = !_neuralVoice);
//               _showSnackBar(
//                 _neuralVoice ? 'Voice replies ON' : 'Voice replies OFF',
//                 _neuralVoice ? Colors.green : Colors.orange,
//               );
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Chat messages
//           Expanded(
//             child: _messages.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(
//                           Icons.chat_bubble_outline,
//                           size: 64,
//                           color: Color(0xFFD4A5B3),
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'Start chatting with Mimi',
//                           style: TextStyle(
//                             color: Color(0xFFD4A5B3),
//                             fontSize: 16,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'Your AI mental health companion',
//                           style: TextStyle(
//                             color: Color(0xFFD4A5B3),
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.all(16),
//                     reverse: true,
//                     itemCount: _messages.reversed.length,
//                     itemBuilder: (context, index) {
//                       final message = _messages.reversed.elementAt(index);
//                       return MessageBubble(
//                         message: message,
//                         onPlayAudio:
//                             message.audioBase64 != null &&
//                                 message.audioBase64!.isNotEmpty
//                             ? () => _playAudioFromBase64(message.audioBase64!)
//                             : null,
//                       );
//                     },
//                   ),
//           ),
//           // Loading indicator
//           if (_isLoading)
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Color(0xFFFF8DA1),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Text(
//                     'Mimi is thinking...',
//                     style: TextStyle(
//                       color: Color(0xFFD4A5B3),
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           // Input bar
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.pink.shade50,
//                   blurRadius: 10,
//                   offset: const Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 // Voice input button
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFFFFB7C5), Color(0xFFFF8DA1)],
//                     ),
//                     shape: BoxShape.circle,
//                   ),
//                   child: CircleAvatar(
//                     backgroundColor: Colors.transparent,
//                     radius: 22,
//                     child: IconButton(
//                       padding: EdgeInsets.zero,
//                       icon: Icon(
//                         _isListening ? Icons.mic : Icons.mic_none,
//                         color: Colors.white,
//                         size: 22,
//                       ),
//                       onPressed: _isLoading ? null : _startVoiceInput,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 // Text input
//                 Expanded(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFFFF0F3),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: TextField(
//                       controller: _messageController,
//                       enabled: !_isLoading,
//                       decoration: InputDecoration(
//                         hintText: _isListening
//                             ? 'Listening...'
//                             : 'Type your message...',
//                         hintStyle: const TextStyle(color: Color(0xFFD4A5B3)),
//                         border: InputBorder.none,
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                       ),
//                       onSubmitted: (_) => _sendMessage(),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 // Send button
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFFFFB7C5), Color(0xFFFF8DA1)],
//                     ),
//                     shape: BoxShape.circle,
//                   ),
//                   child: CircleAvatar(
//                     backgroundColor: Colors.transparent,
//                     radius: 22,
//                     child: IconButton(
//                       padding: EdgeInsets.zero,
//                       icon: Icon(
//                         _isLoading ? Icons.hourglass_empty : Icons.send,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                       onPressed: _isLoading ? null : _sendMessage,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final DateTime timestamp;
//   final String? audioBase64;

//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     required this.timestamp,
//     this.audioBase64,
//   });

//   Map<String, dynamic> toJson() => {
//     'text': text,
//     'isUser': isUser,
//     'timestamp': timestamp.toIso8601String(),
//     'audioBase64': audioBase64,
//   };

//   factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
//     text: json['text'],
//     isUser: json['isUser'],
//     timestamp: DateTime.parse(json['timestamp']),
//     audioBase64: json['audioBase64'],
//   );
// }

// class MessageBubble extends StatelessWidget {
//   final ChatMessage message;
//   final VoidCallback? onPlayAudio;

//   const MessageBubble({super.key, required this.message, this.onPlayAudio});

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.75,
//         ),
//         decoration: BoxDecoration(
//           gradient: message.isUser
//               ? const LinearGradient(
//                   colors: [Color(0xFFFFB7C5), Color(0xFFFFD1DC)],
//                 )
//               : const LinearGradient(
//                   colors: [Color(0xFFE8F0E8), Color(0xFFD4E8D4)],
//                 ),
//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(20),
//             topRight: const Radius.circular(20),
//             bottomLeft: message.isUser
//                 ? const Radius.circular(20)
//                 : const Radius.circular(4),
//             bottomRight: message.isUser
//                 ? const Radius.circular(4)
//                 : const Radius.circular(20),
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               message.text,
//               style: TextStyle(
//                 color: message.isUser
//                     ? const Color(0xFF8B5E6B)
//                     : const Color(0xFF5E6B5E),
//                 fontSize: 15,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
//                   style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
//                 ),
//                 if (!message.isUser && onPlayAudio != null) ...[
//                   const SizedBox(width: 8),
//                   GestureDetector(
//                     onTap: onPlayAudio,
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFFF8DA1).withOpacity(0.2),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.volume_up,
//                         size: 14,
//                         color: Color(0xFFFF8DA1),
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
