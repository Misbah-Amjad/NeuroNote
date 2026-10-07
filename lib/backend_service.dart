import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage_service.dart';
import 'auth_service.dart';

class BackendService {
  static const String baseUrl =
      'https://libaasehamza.store/projects/dashboard9.php';

  static Future<Map<String, dynamic>> _userPayload({
    String? emailOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{};
    final uid = prefs.getString('uid') ?? '';
    final email = emailOverride ?? prefs.getString('userEmail') ?? '';
    if (uid.isNotEmpty) payload['uid'] = uid;
    if (email.isNotEmpty) payload['email'] = email;
    return payload;
  }

  static Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl?action=$action'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) return {'success': false};
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'success': false};
    } catch (e) {
      debugPrint('BackendService.$action failed: $e');
      return {'success': false};
    }
  }

  // ─── Save generated content item ──────────────────────────────
  static Future<void> saveContent({
    required String listKey,
    required Map<String, dynamic> entry,
    String? emailOverride,
  }) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final body = <String, dynamic>{
        ...payload,
        'type': listKey,
        'id': entry['id']?.toString() ?? '',
        'title': entry['title'] ?? '',
        'content': entry['content'] ?? '',
        'action': entry['action'] ?? '',
        'timestamp': entry['timestamp'] ?? DateTime.now().toIso8601String(),
        'date': entry['date'] ?? '',
      };

      for (final key in entry.keys) {
        if (!body.containsKey(key)) body[key] = entry[key];
      }

      await _post('save_content', body);
    } catch (_) {}
  }

  // ─── Delete content item ──────────────────────────────────────
  static Future<void> deleteContent({
    required String listKey,
    required String id,
    String? emailOverride,
  }) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;
      await _post('delete_content', {
        ...payload,
        'type': listKey,
        'id': id,
      });
    } catch (_) {}
  }

  // ─── Pull all content from server into local storage ──────────
  static Future<void> syncContentToLocal({String? emailOverride}) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final response = await _post('get_content', payload);
      if (response['success'] != true || response['data'] == null) return;

      final data = Map<String, dynamic>.from(response['data']);
      final prefs = await SharedPreferences.getInstance();

      // Replace with server data (no merge) so users never see another account's cache.
      Future<void> replaceList(String prefsKey, dynamic serverList) async {
        if (serverList is! List) {
          await prefs.setString(prefsKey, '[]');
          return;
        }
        final items = <Map<String, dynamic>>[];
        for (final item in serverList) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
        items.sort((a, b) {
          final ta = (a['timestamp'] ?? '').toString();
          final tb = (b['timestamp'] ?? '').toString();
          return tb.compareTo(ta);
        });
        await prefs.setString(prefsKey, jsonEncode(items));
      }

      await replaceList(
        await AuthService.scopedKey('neuronote_flashcards'),
        data['flashcards'],
      );
      await replaceList(
        await AuthService.scopedKey('neuronote_quizzes'),
        data['quizzes'],
      );
      await replaceList(
        await AuthService.scopedKey('neuronote_summaries'),
        data['summaries'],
      );
      await replaceList(
        await AuthService.scopedKey('neuronote_audio_notes'),
        data['audio_notes'],
      );
      LocalStorageService.notifyStorageChanged();
    } catch (e) {
      debugPrint('syncContentToLocal failed: $e');
    }
  }

  /// Pull profile + content + progress from MySQL after login or app open.
  static Future<void> syncAllFromServer({String? emailOverride}) async {
    final payload = await _userPayload(emailOverride: emailOverride);
    if (!payload.containsKey('email') && !payload.containsKey('uid')) {
      debugPrint('syncAllFromServer: no uid/email in prefs');
      return;
    }
    await syncContentToLocal(emailOverride: emailOverride);
    await syncChatsToLocal(emailOverride: emailOverride);
    await syncProgressToLocal(emailOverride: emailOverride);
    LocalStorageService.notifyStorageChanged();
  }

  /// Load this user's chat sessions from MySQL into local storage.
  static Future<void> syncChatsToLocal({String? emailOverride}) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final response = await _post('get_chats', payload);
      if (response['success'] != true) return;

      final chats = response['chats'];
      if (chats is! List) return;

      final prefs = await SharedPreferences.getInstance();
      final listKey = await AuthService.scopedKey('chat_history_list');
      final activeKey = await AuthService.scopedKey('neuronote_ai_chat_history');

      final histories = <Map<String, dynamic>>[];
      for (final chat in chats) {
        if (chat is! Map) continue;
        final map = Map<String, dynamic>.from(chat);
        final sessionId = map['session_id']?.toString() ?? '';
        if (sessionId.isEmpty) continue;
        final rawMessages = map['messages'];
        final messages = rawMessages is List
            ? rawMessages
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
            : <Map<String, dynamic>>[];

        histories.add({
          'id': sessionId,
          'title': map['title']?.toString() ?? 'Chat',
          'messages': messages,
          'timestamp':
              map['updated_at']?.toString() ??
              map['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'messageCount':
              (map['message_count'] as num?)?.toInt() ?? messages.length,
        });
      }

      await prefs.setString(listKey, jsonEncode(histories));
      await prefs.remove(activeKey);
    } catch (e) {
      debugPrint('syncChatsToLocal failed: $e');
    }
  }

  /// Upload any local-only AI content to MySQL (for admin panel + re-login restore).
  static Future<void> pushLocalContentToServer({String? emailOverride}) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final prefs = await SharedPreferences.getInstance();
      final keys = {
        await AuthService.scopedKey('neuronote_flashcards'): 'flashcards',
        await AuthService.scopedKey('neuronote_quizzes'): 'quizzes',
        await AuthService.scopedKey('neuronote_summaries'): 'summaries',
        await AuthService.scopedKey('neuronote_audio_notes'): 'audio_notes',
      };

      for (final entry in keys.entries) {
        final raw = prefs.getString(entry.key);
        if (raw == null || raw.isEmpty) continue;
        try {
          final items = jsonDecode(raw) as List<dynamic>;
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              await saveContent(
                listKey: entry.value,
                entry: item,
                emailOverride: emailOverride,
              );
            } else if (item is Map) {
              await saveContent(
                listKey: entry.value,
                entry: Map<String, dynamic>.from(item),
                emailOverride: emailOverride,
              );
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ─── Save streak + weekly progress to backend ─────────────────
  static Future<void> saveProgress({String? emailOverride}) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(
        await AuthService.scopedKey('weekly_progress_data'),
      );
      Map<String, dynamic> progress = {};
      if (progressJson != null) {
        progress = Map<String, dynamic>.from(jsonDecode(progressJson));
      }

      final dailyData = progress['daily_data'];
      List<double> weeklyList = List.filled(7, 0.0);
      final weekStartStr = progress['week_start']?.toString() ?? '';
      if (dailyData is Map && weekStartStr.isNotEmpty) {
        final start = DateTime.tryParse(weekStartStr);
        if (start != null) {
          for (int i = 0; i < 7; i++) {
            final key = DateFormat('yyyy-MM-dd').format(
              start.add(Duration(days: i)),
            );
            weeklyList[i] = (dailyData[key] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      await _post('save_progress', {
        ...payload,
        'current_streak':
            prefs.getInt(await AuthService.scopedKey('current_streak')) ?? 0,
        'best_streak':
            prefs.getInt(await AuthService.scopedKey('best_streak')) ?? 0,
        'last_active_date':
            prefs.getString(await AuthService.scopedKey('last_active_date')) ??
                '',
        'total_activities': progress['total_activities'] ?? 0,
        'weekly_data': weeklyList,
        'week_start': weekStartStr,
      });
    } catch (_) {}
  }

  // ─── Pull progress from server into local storage ─────────────
  static Future<void> syncProgressToLocal({String? emailOverride}) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;

      final response = await _post('get_progress', payload);
      if (response['success'] != true) return;

      final progress = response['progress'];
      if (progress == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        await AuthService.scopedKey('current_streak'),
        (progress['current_streak'] as num?)?.toInt() ?? 0,
      );
      await prefs.setInt(
        await AuthService.scopedKey('best_streak'),
        (progress['best_streak'] as num?)?.toInt() ?? 0,
      );
      final lastActive = progress['last_active_date']?.toString() ?? '';
      if (lastActive.isNotEmpty) {
        await prefs.setString(
          await AuthService.scopedKey('last_active_date'),
          lastActive,
        );
      }

      final weeklyData = progress['weekly_data'];
      final weekStart = progress['week_start']?.toString() ?? '';
      if (weeklyData is List && weeklyData.length == 7 && weekStart.isNotEmpty) {
        final start = DateTime.tryParse(weekStart);
        if (start != null) {
          final Map<String, double> dailyData = {};
          for (int i = 0; i < 7; i++) {
            final date = start.add(Duration(days: i));
            final key = DateFormat('yyyy-MM-dd').format(date);
            dailyData[key] = (weeklyData[i] as num).toDouble();
          }
          await prefs.setString(
            await AuthService.scopedKey('weekly_progress_data'),
            jsonEncode({
              'week_start': weekStart,
              'daily_data': dailyData,
              'total_activities': progress['total_activities'] ?? 0,
              'completed_tasks': 0,
              'last_updated': DateTime.now().toIso8601String(),
            }),
          );
        }
      }
    } catch (_) {}
  }

  // ─── Dashboard stats ────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getStats({
    String? emailOverride,
  }) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) {
        return null;
      }
      final response = await _post('get_stats', payload);
      if (response['success'] == true && response['stats'] != null) {
        return Map<String, dynamic>.from(response['stats']);
      }
    } catch (_) {}
    return null;
  }

  // ─── Save chat session to backend ─────────────────────────────
  static Future<void> saveChat({
    required String sessionId,
    required String title,
    required List<Map<String, dynamic>> messages,
    String? emailOverride,
  }) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;
      await _post('save_chat', {
        ...payload,
        'session_id': sessionId,
        'title': title,
        'messages': messages,
      });
    } catch (_) {}
  }

  // ─── Save uploaded document to backend ────────────────────────
  static Future<void> saveDocument({
    required String fileName,
    required String fileType,
    required String extractedText,
    String? fileBase64,
    String? emailOverride,
  }) async {
    try {
      final payload = await _userPayload(emailOverride: emailOverride);
      if (!payload.containsKey('email') && !payload.containsKey('uid')) return;
      await _post('save_document', {
        ...payload,
        'file_name': fileName,
        'file_type': fileType,
        'extracted_text': extractedText,
        if (fileBase64 != null && fileBase64.isNotEmpty)
          'file_base64': fileBase64,
      });
    } catch (_) {}
  }
}
