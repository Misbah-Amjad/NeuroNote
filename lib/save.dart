import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'navigation.dart';
import 'local_storage_service.dart';
import 'ai_chat.dart';
import 'flashcard_detail.dart';
import 'quiz_detail.dart';
import 'summarymindmap_detail.dart';
import 'audionoteplayer.dart';

// ─── Favorite/Saved Service ────────────────────────────────────
class SavedService {
  static const String _favoritesKey = 'neuronote_favorites';

  // Get all favorites
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await AuthService.scopedKey(_favoritesKey));
    if (data == null || data.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return List<Map<String, dynamic>>.from(list);
    } catch (e) {
      return [];
    }
  }

  // Add to favorites (by unique entry id)
  static Future<void> addFavorite(Map<String, dynamic> item) async {
    try {
      final favorites = await getFavorites();
      final entryId = _entryIdFromItem(item);
      if (entryId.isEmpty) return;

      final exists = favorites.any(
        (f) => _entryIdFromFavorite(f) == entryId,
      );
      if (!exists) {
        favorites.insert(0, {
          ...item,
          'entryId': entryId,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          await AuthService.scopedKey(_favoritesKey),
          jsonEncode(favorites),
        );
      }
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  static String _entryIdFromItem(Map<String, dynamic> item) {
    final data = item['data'];
    if (data is Map && data['id'] != null) {
      return data['id'].toString();
    }
    return item['entryId']?.toString() ?? item['id']?.toString() ?? '';
  }

  static String _entryIdFromFavorite(Map<String, dynamic> item) {
    if (item['entryId'] != null) return item['entryId'].toString();
    final data = item['data'];
    if (data is Map && data['id'] != null) return data['id'].toString();
    return '';
  }

  static Future<void> removeFavoriteById(String entryId) async {
    try {
      final favorites = await getFavorites();
      final updated = favorites
          .where((f) => _entryIdFromFavorite(f) != entryId)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        await AuthService.scopedKey(_favoritesKey),
        jsonEncode(updated),
      );
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  // Remove from favorites
  static Future<void> removeFavorite(String title, String type) async {
    try {
      final favorites = await getFavorites();
      final updated = favorites
          .where((f) => !(f['title'] == title && f['type'] == type))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        await AuthService.scopedKey(_favoritesKey),
        jsonEncode(updated),
      );
      print('Removed from favorites: $title');
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  // Toggle favorite status (uses unique entry id)
  static Future<bool> toggleFavorite(Map<String, dynamic> item) async {
    try {
      final entryId = _entryIdFromItem(item);
      if (entryId.isEmpty) return false;

      final favorites = await getFavorites();
      final exists = favorites.any(
        (f) => _entryIdFromFavorite(f) == entryId,
      );
      if (exists) {
        await removeFavoriteById(entryId);
        return false;
      } else {
        await addFavorite(item);
        return true;
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }

  // Check if item is favorite by entry id
  static Future<bool> isFavorite(String title, String type) async {
    try {
      final favorites = await getFavorites();
      return favorites.any(
        (f) => f['title'] == title && f['type'] == type,
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isFavoriteById(String entryId) async {
    if (entryId.isEmpty) return false;
    try {
      final favorites = await getFavorites();
      return favorites.any((f) => _entryIdFromFavorite(f) == entryId);
    } catch (e) {
      return false;
    }
  }

  // Get all saved content from all sources
  static Future<List<Map<String, dynamic>>> getAllSavedContent() async {
    final List<Map<String, dynamic>> allItems = [];

    try {
      // Get flashcards
      final flashcards = await LocalStorageService.getFlashcards();
      for (var item in flashcards) {
        final title = item['title'] ?? 'Flashcard';
        final type = 'flashcard';
        final entryId = item['id']?.toString() ?? '';
        final isFav = await isFavoriteById(entryId);
        allItems.add({
          'id': entryId,
          'title': title,
          'subtitle': 'Flashcards • ${item['date'] ?? ''}',
          'type': type,
          'icon': Icons.flash_on,
          'iconColor': Colors.deepPurple,
          'data': item,
          'isFavorite': isFav,
        });
      }

      // Get quizzes
      final quizzes = await LocalStorageService.getQuizzes();
      for (var item in quizzes) {
        final title = item['title'] ?? 'Quiz';
        final type = 'quiz';
        final entryId = item['id']?.toString() ?? '';
        final isFav = await isFavoriteById(entryId);
        allItems.add({
          'id': entryId,
          'title': title,
          'subtitle': 'Practice Quiz • ${item['date'] ?? ''}',
          'type': type,
          'icon': Icons.quiz,
          'iconColor': Colors.blueAccent,
          'data': item,
          'isFavorite': isFav,
        });
      }

      // Get summaries
      final summaries = await LocalStorageService.getSummaries();
      for (var item in summaries) {
        final isMindMap = item['action'] == 'mindmap';
        final title = item['title'] ?? (isMindMap ? 'Mind Map' : 'Summary');
        final type = 'summary';
        final entryId = item['id']?.toString() ?? '';
        final isFav = await isFavoriteById(entryId);
        allItems.add({
          'id': entryId,
          'title': title,
          'subtitle':
              '${isMindMap ? 'Mind Map' : 'Summary'} • ${item['date'] ?? ''}',
          'type': type,
          'icon': isMindMap ? Icons.account_tree : Icons.description,
          'iconColor': isMindMap ? Colors.pink : Colors.teal,
          'data': item,
          'isFavorite': isFav,
        });
      }

      // Get audio notes
      final audioNotes = await LocalStorageService.getAudioNotes();
      for (var item in audioNotes) {
        final title = item['title'] ?? 'Audio Note';
        final type = 'audio';
        final entryId = item['id']?.toString() ?? '';
        final isFav = await isFavoriteById(entryId);
        allItems.add({
          'id': entryId,
          'title': title,
          'subtitle': 'Audio Note • ${item['date'] ?? ''}',
          'type': type,
          'icon': Icons.audiotrack,
          'iconColor': Colors.orange,
          'data': item,
          'isFavorite': isFav,
        });
      }

      // Sort by date (newest first)
      allItems.sort((a, b) {
        final dateA = a['data']?['timestamp'] ?? '';
        final dateB = b['data']?['timestamp'] ?? '';
        return dateB.compareTo(dateA);
      });

      return allItems;
    } catch (e) {
      print('Error loading saved content: $e');
      return [];
    }
  }
}

// ─── Saved Screen ─────────────────────────────────────────────

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => SavedScreenState();
}

class SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> savedItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  // ─── Public refresh (called when this tab becomes active again,
  // e.g. after generating new AI content) ─────────────────────────
  Future<void> refreshSaved() async {
    await _loadSavedItems();
  }

  Future<void> _loadSavedItems() async {
    setState(() => isLoading = true);
    try {
      final items = await SavedService.getAllSavedContent();
      setState(() {
        savedItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading saved items: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final bool newStatus = await SavedService.toggleFavorite(item);

    setState(() {
      final index = savedItems.indexWhere(
        (i) =>
            i['id'] == item['id'] ||
            (i['title'] == item['title'] && i['type'] == item['type']),
      );
      if (index != -1) {
        savedItems[index]['isFavorite'] = newStatus;
      }
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus ? '❤️ Added to favorites' : 'Removed from favorites',
        ),
        backgroundColor: newStatus ? Colors.teal : Colors.red,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          },
        ),
        title: Text(
          'Saved Materials',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            tooltip: "View Favorites",
            onPressed: () {
              final favorites = savedItems
                  .where((item) => item['isFavorite'] == true)
                  .toList();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoriteScreen(
                    favoriteItems: favorites,
                    onFavoriteToggled: _loadSavedItems,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: _loadSavedItems,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.9,
              child: Lottie.asset(
                'assets/animations/Sparkles Animation.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal))
          else if (savedItems.isEmpty)
            _buildEmptyState()
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: ListView.builder(
                itemCount: savedItems.length,
                itemBuilder: (context, index) {
                  final item = savedItems[index];
                  final isFavorite = item['isFavorite'] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.red.shade50.withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      border: isFavorite
                          ? Border.all(color: Colors.red.shade200, width: 1)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (item['iconColor'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: item['iconColor'] as Color,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item['title'] ?? 'Untitled',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item['subtitle'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey.shade400,
                              size: 24,
                            ),
                            onPressed: () => _toggleFavorite(item),
                            tooltip: isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                              size: 22,
                            ),
                            onPressed: () => _deleteItem(item),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      onTap: () {
                        _openItemDetail(item);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Saved Content Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate content from AI Chat to see it here!',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Go to AI Chat',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete content?', style: GoogleFonts.poppins()),
        content: Text(
          'This will permanently remove "${item['title']}".',
          style: GoogleFonts.poppins(),
        ),
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

    final type = item['type']?.toString() ?? '';
    final entryId = item['id']?.toString() ?? '';
    final storageType = type == 'audio' ? 'audio_note' : type;
    if (entryId.isNotEmpty) {
      await LocalStorageService.deleteContentById(storageType, entryId);
    }
    await _loadSavedItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content deleted'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _openItemDetail(Map<String, dynamic> item) {
    final type = item['type'] ?? '';
    final data = item['data'] ?? {};
    final title = item['title'] ?? 'Content';

    switch (type) {
      case 'flashcard':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FlashcardDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'quiz':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                QuizDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'summary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SummaryMindMapDetailScreen(topicTitle: title, topicData: data),
          ),
        );
        break;
      case 'audio':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AudioNotePlayerScreen(
              title: title,
              subtitle: data['preview']?.toString() ?? 'Audio note',
              scriptContent: data['content']?.toString() ?? '',
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: $title'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.teal,
          ),
        );
    }
  }
}

/// ✅ Favorite Screen
class FavoriteScreen extends StatefulWidget {
  final List<Map<String, dynamic>> favoriteItems;
  final VoidCallback? onFavoriteToggled;

  const FavoriteScreen({
    super.key,
    required this.favoriteItems,
    this.onFavoriteToggled,
  });

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  late List<Map<String, dynamic>> favorites;

  @override
  void initState() {
    super.initState();
    favorites = List.from(widget.favoriteItems);
  }

  Future<void> _removeFromFavorites(Map<String, dynamic> item) async {
    await SavedService.removeFavorite(item['title'], item['type']);
    setState(() {
      favorites.removeWhere(
        (f) => f['title'] == item['title'] && f['type'] == item['type'],
      );
    });
    widget.onFavoriteToggled?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from favorites'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (favorites.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Text(
              'Favorite Materials',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${favorites.length}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      'Clear All Favorites?',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    content: Text(
                      'All favorites will be permanently removed.',
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
                          for (var item in favorites) {
                            await SavedService.removeFavorite(
                              item['title'],
                              item['type'],
                            );
                          }
                          Navigator.pop(c);
                          widget.onFavoriteToggled?.call();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('All favorites cleared'),
                              backgroundColor: Colors.teal,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Clear all favorites',
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.9,
              child: Lottie.asset(
                'assets/animations/Sparkles Animation.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),
          if (favorites.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No favorites yet ❤️",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tap the heart icon to save your favorites",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final item = favorites[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.red.shade100, width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (item['iconColor'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: item['iconColor'] as Color,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item['title'] ?? 'Untitled',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item['subtitle'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 24,
                        ),
                        onPressed: () => _removeFromFavorites(item),
                        tooltip: 'Remove from favorites',
                      ),
                      onTap: () {
                        final type = item['type'] ?? '';
                        final data = item['data'] ?? {};
                        final title = item['title'] ?? 'Content';

                        switch (type) {
                          case 'flashcard':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FlashcardDetailScreen(
                                  topicTitle: title,
                                  topicData: data,
                                ),
                              ),
                            );
                            break;
                          case 'quiz':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizDetailScreen(
                                  topicTitle: title,
                                  topicData: data,
                                ),
                              ),
                            );
                            break;
                          case 'summary':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SummaryMindMapDetailScreen(
                                      topicTitle: title,
                                      topicData: data,
                                    ),
                              ),
                            );
                            break;
                          case 'audio':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioNotePlayerScreen(
                                  title: title,
                                  subtitle: data['preview']?.toString() ?? 'Audio note',
                                  scriptContent: data['content']?.toString() ?? '',
                                ),
                              ),
                            );
                            break;
                          default:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Opening: $title'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: Colors.teal,
                              ),
                            );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
