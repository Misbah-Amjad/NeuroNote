// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'backend_service.dart';
import 'notification.dart';

class LocalStorageService {
  static final ValueNotifier<int> storageVersion = ValueNotifier(0);

  // Keys for different content types
  static const String _flashcardsKey = 'neuronote_flashcards';
  static const String _quizzesKey = 'neuronote_quizzes';
  static const String _summariesKey = 'neuronote_summaries';
  static const String _audioNotesKey = 'neuronote_audio_notes';
  static const String _favoritesKey = 'neuronote_favorites';

  static Future<String> _scoped(String base) => AuthService.scopedKey(base);

  static void _notifyStorageChanged() {
    storageVersion.value++;
  }

  /// Call after server sync so dashboard/saved tabs refresh.
  static void notifyStorageChanged() => _notifyStorageChanged();

  // ─── Flashcards ──────────────────────────────────────────────
  static Future<void> saveFlashcard(Map<String, dynamic> flashcard) async {
    final prefs = await SharedPreferences.getInstance();
    final flashcards = await getFlashcards();
    flashcards.insert(0, flashcard);
    await prefs.setString(await _scoped(_flashcardsKey), jsonEncode(flashcards));
    // Sync to backend (fire-and-forget)
    BackendService.saveContent(listKey: 'flashcards', entry: flashcard);
  }

  static Future<List<dynamic>> getFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await _scoped(_flashcardsKey));
    if (data == null) return [];
    try {
      return jsonDecode(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _scoped(_flashcardsKey));
  }

  // ─── Quizzes ──────────────────────────────────────────────────
  static Future<void> saveQuiz(Map<String, dynamic> quiz) async {
    final prefs = await SharedPreferences.getInstance();
    final quizzes = await getQuizzes();
    quizzes.insert(0, quiz);
    await prefs.setString(await _scoped(_quizzesKey), jsonEncode(quizzes));
    // Sync to backend (fire-and-forget)
    BackendService.saveContent(listKey: 'quizzes', entry: quiz);
  }

  static Future<List<dynamic>> getQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await _scoped(_quizzesKey));
    if (data == null) return [];
    try {
      return jsonDecode(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _scoped(_quizzesKey));
  }

  // ─── Summaries & Mind Maps ──────────────────────────────────
  static Future<void> saveSummary(Map<String, dynamic> summary) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = await getSummaries();
    summaries.insert(0, summary);
    await prefs.setString(await _scoped(_summariesKey), jsonEncode(summaries));
    // Sync to backend (fire-and-forget)
    BackendService.saveContent(listKey: 'summaries', entry: summary);
  }

  static Future<List<dynamic>> getSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await _scoped(_summariesKey));
    if (data == null) return [];
    try {
      return jsonDecode(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _scoped(_summariesKey));
  }

  // ─── Audio Notes ─────────────────────────────────────────────
  static Future<void> saveAudioNote(Map<String, dynamic> audioNote) async {
    final prefs = await SharedPreferences.getInstance();
    final audioNotes = await getAudioNotes();
    audioNotes.insert(0, audioNote);
    await prefs.setString(await _scoped(_audioNotesKey), jsonEncode(audioNotes));
    // Sync to backend (fire-and-forget)
    BackendService.saveContent(listKey: 'audio_notes', entry: audioNote);
  }

  static Future<List<dynamic>> getAudioNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(await _scoped(_audioNotesKey));
    if (data == null) return [];
    try {
      return jsonDecode(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearAudioNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _scoped(_audioNotesKey));
  }

  static Future<void> attachImageToLatestSummary({
    required String title,
    String? imageBase64,
    String? imageMimeType,
    String? imageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = await getSummaries();
    if (summaries.isEmpty) return;

    var updated = false;
    for (var i = 0; i < summaries.length; i++) {
      final item = summaries[i];
      if (item is! Map) continue;
      if (item['title']?.toString() == title) {
        final entry = Map<String, dynamic>.from(item);
        if (imageBase64 != null) entry['imageBase64'] = imageBase64;
        if (imageMimeType != null) entry['imageMimeType'] = imageMimeType;
        if (imageUrl != null) entry['imageUrl'] = imageUrl;
        summaries[i] = entry;
        updated = true;
        break;
      }
    }

    if (!updated && summaries.first is Map) {
      final entry = Map<String, dynamic>.from(summaries.first as Map);
      if (imageBase64 != null) entry['imageBase64'] = imageBase64;
      if (imageMimeType != null) entry['imageMimeType'] = imageMimeType;
      if (imageUrl != null) entry['imageUrl'] = imageUrl;
      summaries[0] = entry;
    }

    await prefs.setString(await _scoped(_summariesKey), jsonEncode(summaries));
    _notifyStorageChanged();
  }

  // ─── Helper: Save Generated Content from AI ──────────────────
  // ─── Save Generated Content with Image ──────────────────────
  static Future<String> saveGeneratedContent({
    required String type,
    required String title,
    required String content,
    required String action,
    Map<String, dynamic>? extraData,
    String? imageBase64,
    String? imageMimeType,
    String? imageUrl,
  }) async {
    final now = DateTime.now();
    final entryId = now.millisecondsSinceEpoch.toString();
    final entry = {
      'id': entryId,
      'title': title,
      'content': content,
      'action': action,
      'timestamp': now.toIso8601String(),
      'date': '${now.day}/${now.month}/${now.year}',
      ...?extraData,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (imageMimeType != null) 'imageMimeType': imageMimeType,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    switch (type) {
      case 'flashcard':
        await saveFlashcard(entry);
        await NotificationService.trackFlashcardGenerated();
        break;
      case 'quiz':
        await saveQuiz(entry);
        await NotificationService.trackQuizGenerated();
        break;
      case 'summary':
        await saveSummary(entry);
        final act = action.toLowerCase();
        if (act == 'mindmap' || act == 'summary_mindmap') {
          await NotificationService.trackMindMapGenerated();
        } else {
          await NotificationService.trackSummaryGenerated();
        }
        break;
      case 'audio_note':
        await saveAudioNote(entry);
        await NotificationService.trackAudioNoteGenerated();
        break;
    }

    _notifyStorageChanged();
    return entryId;
  }

  static Future<void> deleteContentById(String type, String id) async {
    final prefs = await SharedPreferences.getInstance();
    String baseKey;
    String listKey;
    Future<List<dynamic>> Function() getter;

    switch (type) {
      case 'flashcard':
        baseKey = _flashcardsKey;
        listKey = 'flashcards';
        getter = getFlashcards;
        break;
      case 'quiz':
        baseKey = _quizzesKey;
        listKey = 'quizzes';
        getter = getQuizzes;
        break;
      case 'summary':
        baseKey = _summariesKey;
        listKey = 'summaries';
        getter = getSummaries;
        break;
      case 'audio_note':
      case 'audio':
        baseKey = _audioNotesKey;
        listKey = 'audio_notes';
        getter = getAudioNotes;
        break;
      default:
        return;
    }

    final items = await getter();
    items.removeWhere(
      (item) => item is Map && item['id']?.toString() == id,
    );
    await prefs.setString(await _scoped(baseKey), jsonEncode(items));
    await _removeFavoriteByEntryId(id);
    _notifyStorageChanged();
    BackendService.deleteContent(listKey: listKey, id: id);
  }

  static Future<void> _removeFavoriteByEntryId(String entryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(await _scoped(_favoritesKey));
      if (data == null || data.isEmpty) return;
      final List<dynamic> favorites = jsonDecode(data);
      favorites.removeWhere(
        (f) =>
            f is Map &&
            (f['entryId']?.toString() == entryId ||
                f['data']?['id']?.toString() == entryId),
      );
      await prefs.setString(await _scoped(_favoritesKey), jsonEncode(favorites));
    } catch (_) {}
  }
}
