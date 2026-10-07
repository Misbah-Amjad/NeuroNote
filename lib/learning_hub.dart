import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'navigation.dart';
import 'ai_chat.dart';

class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({super.key});

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  List<dynamic> _topics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('learning_hub_items');

      List<dynamic> items = [];
      if (data != null) {
        items = jsonDecode(data);
      }

      if (items.isEmpty) {
        items = _getDefaultItems();
        await prefs.setString('learning_hub_items', jsonEncode(items));
      }

      setState(() {
        _topics = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading topics: $e');
      setState(() => isLoading = false);
    }
  }

  List<dynamic> _getDefaultItems() {
    return [
      {
        'id': '1',
        'title': 'Human Brain Structure',
        'description':
            'Neuroscience fundamentals - Learn about the parts of the brain',
        'category': 'Science',
      },
      {
        'id': '2',
        'title': 'Cognitive Psychology',
        'description': 'How the mind processes information and learns',
        'category': 'Psychology',
      },
      {
        'id': '3',
        'title': 'AI in Education',
        'description': 'How AI is transforming learning and teaching methods',
        'category': 'Technology',
      },
    ];
  }

  Future<void> _refreshTopics() async {
    await _loadTopics();
  }

  // ─── Navigate to AI Chat with direct action ──────────────────
  void _navigateToAIWithAction(String action, String content, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          uploadedFileName: title,
          uploadedFileContent: content,
          initialAction: action, // Direct action - no modal
          initialContent: content,
        ),
      ),
    );
  }

  // ─── Handle popup menu actions ──────────────────────────────
  void _handleMenuAction(String value, Map<String, dynamic> topic) {
    final topicTitle = topic['title'] ?? 'this topic';
    final topicDesc = topic['description'] ?? '';
    final content = '$topicTitle\n\n$topicDesc';

    String action = '';
    switch (value) {
      case "Flashcards":
        action = 'flashcard';
        break;
      case "Audio Note":
        action = 'voice';
        break;
      case "Summary and mindmaps":
        action = 'summarize';
        break;
      case "Practice Quiz":
        action = 'quiz';
        break;
      default:
        action = 'explain';
    }

    _navigateToAIWithAction(action, content, topicTitle);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTopics = _topics.where((topic) {
      final title = topic["title"]?.toLowerCase() ?? '';
      final desc = topic["description"]?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return title.contains(query) || desc.contains(query);
    }).toList();

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
              MaterialPageRoute(builder: (context) => MainNavigation()),
            );
          },
        ),
        title: Text(
          'Learning Hub',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: _refreshTopics,
            tooltip: 'Refresh',
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
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: "Search topics or books...",
                    prefixIcon: const Icon(Icons.search),
                    iconColor: Colors.teal,
                    filled: true,
                    fillColor: const Color.fromARGB(255, 227, 252, 250),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      )
                    : filteredTopics.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No topics found',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create content from AI Chat!',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AIChatScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Go to AI Chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTopics.length,
                        itemBuilder: (context, index) {
                          final topic = filteredTopics[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.book,
                                  color: Colors.teal,
                                ),
                              ),
                              title: Text(
                                topic["title"] ?? 'Untitled',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topic["description"] ?? '',
                                    style: TextStyle(color: Colors.grey[600]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (topic["category"] != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        topic["category"],
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) =>
                                    _handleMenuAction(value, topic),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: "Flashcards",
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.flash_on,
                                          color: Colors.teal,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text("📚 Make Flashcards"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: "Audio Note",
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.audiotrack,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text("🎧 Generate Audio Note"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: "Summary and mindmaps",
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.summarize,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text("📝 Summary & Mindmaps"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: "Practice Quiz",
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.quiz,
                                          color: Colors.deepOrange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text("📝 Practice Quiz"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
