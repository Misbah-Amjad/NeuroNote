import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl =
      'https://libaasehamza.store/projects/dashboard9.php';

  static Map<String, dynamic> _connectionError(Object e) {
    final details = e.toString();
    if (details.contains('TimeoutException')) {
      return {
        'success': false,
        'message': 'Server is taking too long. Please try again.',
      };
    }
    if (details.contains('Failed to fetch') ||
        details.contains('XMLHttpRequest') ||
        details.contains('Connection refused') ||
        details.contains('SocketException')) {
      return {
        'success': false,
        'message':
            'Cannot reach auth server. Internet may be fine — try another network, disable VPN/firewall, or open libaasehamza.store in browser.',
      };
    }
    return {
      'success': false,
      'message': 'Server connection failed. Please try again later.',
    };
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

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Invalid server response'};
    } catch (e) {
      return _connectionError(e);
    }
  }

  // ─── Save session data (includes uid) ─────────────────────────
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
    if (userData['loggedIn'] == true) {
      await prefs.setBool('isLoggedIn', true);
    }
    // Persist uid separately for quick access
    if (userData['uid'] != null && userData['uid'].toString().isNotEmpty) {
      await prefs.setString('uid', userData['uid'].toString());
    }
    // Persist email separately for quick access
    if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
      await prefs.setString(
        'userEmail',
        userData['email'].toString().toLowerCase(),
      );
    }
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  // ─── Save profile data locally and optionally to backend ──────
  // [syncToServer] should be false when we are already loading FROM the server
  // to avoid an infinite save→fetch→save loop.
  static Future<void> saveProfileData(
    Map<String, dynamic> profileData, {
    bool syncToServer = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final toStore = Map<String, dynamic>.from(profileData);
    final b64 = toStore['userImageBase64']?.toString() ?? '';
    if (b64.length >= 400000) {
      toStore['userImageBase64'] = '';
    }
    await prefs.setString('profile_data', jsonEncode(toStore));

    if (profileData['userName'] != null) {
      await prefs.setString('userName', profileData['userName']);
    }
    if (profileData['userBio'] != null) {
      await prefs.setString('userBio', profileData['userBio']);
    }
    if (profileData['userEmail'] != null) {
      await prefs.setString(
        'userEmail',
        profileData['userEmail'].toString().toLowerCase(),
      );
    }
    if (profileData['userPhone'] != null) {
      await prefs.setString('userPhone', profileData['userPhone']);
    }
    if (profileData['userImageBase64'] != null) {
      final b64 = profileData['userImageBase64'].toString();
      // Web SharedPreferences chokes on very large base64 strings.
      if (b64.isNotEmpty && b64.length < 400000) {
        await prefs.setString('userImageBase64', b64);
      }
    }
    if (profileData['userImage'] != null) {
      await prefs.setString('userImage', profileData['userImage']);
    }
    if (profileData['birthDate'] != null) {
      await prefs.setString('birthDate', profileData['birthDate']);
    }
    if (profileData['gender'] != null) {
      await prefs.setString('gender', profileData['gender']);
    }
    if (profileData['interests'] != null) {
      final interests = profileData['interests'];
      if (interests is List) {
        await prefs.setStringList('interests', List<String>.from(interests));
      } else if (interests is String) {
        await prefs.setString('interests_str', interests);
      }
    }
    if (profileData['reason'] != null) {
      await prefs.setString('reason', profileData['reason']);
    }
    // Only ever set profileComplete=true when saving; never downgrade from server fetch
    if (profileData['profileComplete'] == true) {
      await prefs.setBool('profileComplete', true);
    } else if (syncToServer && profileData['profileComplete'] == false) {
      await prefs.setBool('profileComplete', false);
    }

    // Sync to backend only when explicitly requested
    if (!syncToServer) return;

    final uid = prefs.getString('uid') ?? '';
    final email =
        profileData['userEmail'] ?? prefs.getString('userEmail') ?? '';

    if (uid.isEmpty && email.isEmpty) return;

    try {
      final interestsVal =
          profileData['interests'] ??
          prefs.getStringList('interests') ??
          [];
      final isCompleteVal =
          profileData['profileComplete'] ??
          prefs.getBool('profileComplete') ??
          false;

      final response = await _post('save_profile', {
        if (uid.isNotEmpty) 'uid': uid,
        if (email.isNotEmpty) 'email': email,
        'userName': profileData['userName'] ?? prefs.getString('userName') ?? '',
        'userBio': profileData['userBio'] ?? prefs.getString('userBio') ?? '',
        'userPhone':
            profileData['userPhone'] ?? prefs.getString('userPhone') ?? '',
        'gender': profileData['gender'] ?? prefs.getString('gender') ?? '',
        'birthDate':
            profileData['birthDate'] ?? prefs.getString('birthDate') ?? '',
        'interests': interestsVal,
        'reason': profileData['reason'] ?? prefs.getString('reason') ?? '',
        'userImageBase64':
            profileData['userImageBase64'] ??
            prefs.getString('userImageBase64') ??
            '',
        'profileComplete': isCompleteVal,
      });

      if (response['success'] == true && response['profile'] != null) {
        await saveProfileData(
          Map<String, dynamic>.from(response['profile']),
          syncToServer: false,
        );
      }
    } catch (e) {
      debugPrint('Error saving profile to server: $e');
    }
  }

  // ─── Fetch profile from backend (backend is source of truth) ──
  // Always sends uid (if available) so the server can locate the user even if
  // the email changes in the future. Falls back to email-only lookup.
  static Future<Map<String, dynamic>?> getProfileFromServer(
    String email,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid') ?? '';

      final payload = <String, dynamic>{};
      if (uid.isNotEmpty) payload['uid'] = uid;
      if (email.isNotEmpty) payload['email'] = email;
      if (payload.isEmpty) return null;

      final response = await _post('get_profile', payload);
      if (response['success'] == true && response['profile'] != null) {
        final profile = Map<String, dynamic>.from(response['profile']);

        // Persist profile locally — do NOT re-sync to server (syncToServer: false)
        // to prevent an infinite loop.
        await saveProfileData(profile, syncToServer: false);

        if (profile['profileComplete'] == true) {
          await markProfileComplete();
        }

        // Also store uid returned by the server (in case it wasn't stored yet)
        if (profile['uid'] != null &&
            profile['uid'].toString().isNotEmpty &&
            uid.isEmpty) {
          await prefs.setString('uid', profile['uid'].toString());
        }

        return profile;
      }
      debugPrint('getProfileFromServer failed: ${response['message'] ?? response}');
    } catch (e) {
      debugPrint('Error fetching profile from server: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('profile_data');
    if (data != null) {
      return jsonDecode(data);
    }

    final userName = prefs.getString('userName');
    final userBio = prefs.getString('userBio');
    final userEmail = prefs.getString('userEmail');
    final userPhone = prefs.getString('userPhone');
    final userImageBase64 = prefs.getString('userImageBase64');
    final userImage = prefs.getString('userImage');

    if (userName != null || userEmail != null) {
      return {
        'userName': userName ?? 'Guest User',
        'userBio': userBio ?? 'Student',
        'userEmail': userEmail ?? '',
        'userPhone': userPhone ?? '',
        'userImageBase64': userImageBase64 ?? '',
        'userImage': userImage ?? '',
      };
    }

    return null;
  }

  static const String _sessionEmailKey = '_active_session_email';

  /// Unique suffix per logged-in user for local storage keys.
  static Future<String> userStoragePrefix() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid') ?? '';
    if (uid.isNotEmpty) return 'u$uid';
    final email = (prefs.getString('userEmail') ?? '').toLowerCase();
    if (email.isNotEmpty) {
      return email.replaceAll('@', '_at_').replaceAll('.', '_');
    }
    return 'guest';
  }

  static Future<String> scopedKey(String base) async {
    return '${base}_${await userStoragePrefix()}';
  }

  /// Wipe cached AI content, chats, notifications, progress, profile for local isolation.
  static Future<void> clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await userStoragePrefix();
    const keys = [
      'neuronote_flashcards',
      'neuronote_quizzes',
      'neuronote_summaries',
      'neuronote_audio_notes',
      'neuronote_favorites',
      'neuronote_ai_chat_history',
      'chat_history_list',
      'neuronote_notifications',
      'weekly_progress_data',
      'current_streak',
      'best_streak',
      'last_active_date',
      'last_streak_notify_date',
      'last_missed_notify_date',
      'neuronote_quiz_history',
      'neuronote_quiz_stats',
      'neuronote_api_cache',
      'neuronote_last_fetch',
      'profile_data',
      'profileComplete',
      'userName',
      'userBio',
      'userEmail',
      'userPhone',
      'userImage',
      'userImageBase64',
      'birthDate',
      'gender',
      'interests',
      'interests_str',
      'reason',
    ];
    for (final key in keys) {
      await prefs.remove(key);
      if (prefix != 'guest') {
        await prefs.remove('${key}_$prefix');
      }
    }
  }

  /// If a different user signs in, clear the previous user's local cache first.
  static Future<void> ensureUserSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = email.trim().toLowerCase();
    final previous =
        (prefs.getString(_sessionEmailKey) ?? '').toLowerCase();
    if (previous.isNotEmpty && previous != normalized) {
      await clearLocalUserData();
    }
    await prefs.setString(_sessionEmailKey, normalized);
    await prefs.setString('userEmail', normalized);
  }

  // ─── Logout: clear session only (keep local cache for same user re-login) ─
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('isLoggedIn');
    await prefs.remove('uid');
    await prefs.remove('rememberMe');
    await prefs.remove('email');
    await prefs.remove('password');
    // Keep _sessionEmailKey + local user data so same account gets instant restore.
    // Different account login still clears via ensureUserSession().
  }

  static Future<void> markProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profileComplete', true);
  }

  /// After login: fetch profile from MySQL, restore local data, decide dashboard vs setup.
  static Future<bool> completeLoginFlow(
    String email,
    Map<String, dynamic> loginResult,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    await ensureUserSession(normalizedEmail);

    await saveUserData({
      'email': normalizedEmail,
      'name': loginResult['name'] ?? 'User',
      'uid': loginResult['uid'] ?? '',
      'loggedIn': true,
    });

    // Login API already reads profile_complete from MySQL
    if (loginResult['profileComplete'] == true) {
      await markProfileComplete();
    }

    var serverProfile = await getProfileFromServer(normalizedEmail);
    await ensureProfileOnServer(normalizedEmail);
    serverProfile =
        await getProfileFromServer(normalizedEmail) ?? serverProfile;

    if (loginResult['profileComplete'] == true) return true;
    if (profileHasSetupData(serverProfile)) {
      await markProfileComplete();
      return true;
    }
    if (await isProfileComplete()) return true;
    if (profileHasSetupData(await getProfileData())) {
      await markProfileComplete();
      return true;
    }

    return false;
  }

  static Future<Map<String, dynamic>> signUp(
    String email,
    String password,
  ) async {
    return _post('signup', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return _post('login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _post('forgot_password', {'email': email});
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    return _post('reset_password', {
      'email': email,
      'new_password': newPassword,
    });
  }

  static Future<Map<String, dynamic>> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl?action=change_password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn') == true) return true;
    final userData = await getUserData();
    return userData != null && userData['loggedIn'] == true;
  }

  static bool profileHasSetupData(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    if (profile['profileComplete'] == true) return true;

    // Do NOT count userName — signup auto-fills it from email prefix.
    final fields = [
      profile['gender'],
      profile['birthDate'],
      profile['userPhone'],
      profile['userImage'],
      profile['userBio'],
      profile['reason'],
      profile['goals'],
    ];
    for (final field in fields) {
      if (field != null && field.toString().trim().isNotEmpty) return true;
    }
    final interests = profile['interests'];
    if (interests is List && interests.isNotEmpty) return true;
    if (interests is String &&
        interests.trim().isNotEmpty &&
        interests.trim() != '[]') {
      return true;
    }
    return false;
  }

  static Future<bool> isProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('profileComplete') ?? false;
  }

  /// Server → login response → local cache (never force setup if user already completed locally)
  static Future<bool> resolveProfileComplete({
    Map<String, dynamic>? loginResult,
    Map<String, dynamic>? serverProfile,
  }) async {
    if (serverProfile != null && serverProfile['profileComplete'] == true) {
      return true;
    }
    if (loginResult != null && loginResult['profileComplete'] == true) {
      return true;
    }
    if (await isProfileComplete()) return true;
    return profileHasSetupData(await getProfileData());
  }

  /// Push profile to server and fix profile_complete flag in MySQL if needed.
  static Future<void> ensureProfileOnServer(String email) async {
    final profile = await getProfileData();
    if (profile == null) return;

    final prefs = await SharedPreferences.getInstance();
    final shouldSync = (prefs.getBool('profileComplete') ?? false) ||
        profileHasSetupData(profile);
    if (!shouldSync) return;

    profile['profileComplete'] = true;
    profile['userEmail'] = email;
    await saveProfileData(profile);
    await getProfileFromServer(email);
  }
}
