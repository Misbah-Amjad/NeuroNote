<?php
/**
 * NeuroNote — All-in-one Backend (App API + Admin Panel)
 * Upload to: https://libaasehamza.store/projects/dashboard9.php
 * Admin panel: https://libaasehamza.store/projects/dashboard9.php?action=admin
 * Create folder: projects/uploads/ (chmod 755)
 */
require_once __DIR__ . '/config.php';

session_start();
function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]
        );
    }
    return $pdo;
}

function jsonOut($data) {
    echo json_encode($data);
    exit();
}

function getInput(): array {
    $raw = file_get_contents('php://input');
    $json = json_decode($raw, true);
    return is_array($json) ? $json : [];
}

function ensureUploadDir() {
    if (!is_dir(UPLOAD_DIR)) {
        mkdir(UPLOAD_DIR, 0755, true);
    }
}

function saveBase64Image(string $base64, string $prefix, int $userId): ?string {
  if (empty($base64)) return null;
  ensureUploadDir();
  $base64 = preg_replace('#^data:image/\w+;base64,#i', '', $base64);
  $data = base64_decode($base64, true);
  if ($data === false || strlen($data) < 10) return null;
  $filename = $prefix . '_' . $userId . '_' . time() . '.jpg';
  $path = UPLOAD_DIR . $filename;
  if (file_put_contents($path, $data) === false) return null;
  return 'uploads/' . $filename;
}

function imageUrl(?string $path): string {
    if (empty($path)) return '';
    if (strpos($path, 'http') === 0) {
        // Re-proxy old direct upload URLs so Flutter web can load them (CORS).
        if (preg_match('#/uploads/([^?]+)$#', $path, $m)) {
            return BASE_URL . SELF_FILE . '?action=serve_file&path=' . urlencode('uploads/' . $m[1]);
        }
        return $path;
    }
    $clean = ltrim($path, '/');
    return BASE_URL . SELF_FILE . '?action=serve_file&path=' . urlencode($clean);
}

function serveUploadFile(string $relPath): void {
    $relPath = str_replace(['..', '\\'], '', $relPath);
    $relPath = ltrim($relPath, '/');
    if (!preg_match('#^uploads/[a-zA-Z0-9._-]+$#', $relPath)) {
        http_response_code(403);
        exit('Forbidden');
    }
    $full = __DIR__ . '/' . $relPath;
    if (!is_file($full)) {
        http_response_code(404);
        exit('Not found');
    }
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, OPTIONS');
    header('Cache-Control: public, max-age=86400');
    $ext = strtolower(pathinfo($full, PATHINFO_EXTENSION));
    $types = [
        'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png',
        'gif' => 'image/gif', 'webp' => 'image/webp', 'pdf' => 'application/pdf',
    ];
    header('Content-Type: ' . ($types[$ext] ?? 'application/octet-stream'));
    readfile($full);
    exit;
}

function isAdminLoggedIn(): bool {
    return isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true;
}

/** Delete user and all related rows from MySQL (and upload files). */
function deleteUserCompletely(PDO $pdo, int $userId): bool {
    if ($userId <= 0) {
        return false;
    }

    $st = $pdo->prepare('SELECT id FROM users WHERE id = ? LIMIT 1');
    $st->execute([$userId]);
    if (!$st->fetch()) {
        return false;
    }

    $st = $pdo->prepare('SELECT profile_image FROM user_profiles WHERE user_id = ?');
    $st->execute([$userId]);
    $profile = $st->fetch() ?: [];

    $st = $pdo->prepare('SELECT file_path FROM user_documents WHERE user_id = ?');
    $st->execute([$userId]);
    $documents = $st->fetchAll();

    $pdo->beginTransaction();
    try {
        $pdo->prepare('DELETE FROM chat_messages WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM chat_sessions WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM user_content WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM user_documents WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM user_progress WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM user_profiles WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);
        $pdo->commit();
    } catch (Exception $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }

    if (!empty($profile['profile_image'])) {
        $path = __DIR__ . '/' . ltrim($profile['profile_image'], '/');
        if (is_file($path)) {
            @unlink($path);
        }
    }
    foreach ($documents as $doc) {
        if (empty($doc['file_path'])) {
            continue;
        }
        $path = __DIR__ . '/' . ltrim($doc['file_path'], '/');
        if (is_file($path)) {
            @unlink($path);
        }
    }

    return true;
}

function getMysqlUsers(): array {
    $pdo = db();
    $sql = 'SELECT u.id, u.email, u.name, u.profile_complete, u.created_at,
                   p.phone, p.gender, p.birth_date, p.interests, p.reason, p.goals, p.profile_image,
                   pr.current_streak, pr.best_streak, pr.total_activities
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            LEFT JOIN user_progress pr ON pr.user_id = u.id
            ORDER BY u.id DESC';
    $users = $pdo->query($sql)->fetchAll();
    foreach ($users as &$u) {
        $uid = (int)$u['id'];
        $st = $pdo->prepare(
            'SELECT content_type, COUNT(*) c FROM user_content WHERE user_id=? GROUP BY content_type'
        );
        $st->execute([$uid]);
        $counts = ['flashcards' => 0, 'quizzes' => 0, 'summaries' => 0, 'audio_notes' => 0];
        foreach ($st->fetchAll() as $r) {
            $counts[$r['content_type']] = (int)$r['c'];
        }
        $u['flashcard_count'] = $counts['flashcards'];
        $u['quiz_count'] = $counts['quizzes'];
        $u['summary_count'] = $counts['summaries'];
        $u['audio_count'] = $counts['audio_notes'];
        $st = $pdo->prepare('SELECT COUNT(*) FROM chat_sessions WHERE user_id=?');
        $st->execute([$uid]);
        $u['chat_count'] = (int)$st->fetchColumn();
        $st = $pdo->prepare('SELECT COUNT(*) FROM user_documents WHERE user_id=?');
        $st->execute([$uid]);
        $u['document_count'] = (int)$st->fetchColumn();
        $u['profile_image_url'] = imageUrl($u['profile_image'] ?? '');
    }
    unset($u);
    return $users;
}

function findUserId(?string $uid, ?string $email): ?int {
    $pdo = db();
    if ($uid) {
        $st = $pdo->prepare('SELECT id FROM users WHERE id = ? LIMIT 1');
        $st->execute([(int)$uid]);
        $row = $st->fetch();
        if ($row) return (int)$row['id'];
    }
    if ($email) {
        $st = $pdo->prepare('SELECT id FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1');
        $st->execute([trim($email)]);
        $row = $st->fetch();
        if ($row) return (int)$row['id'];
    }
    return null;
}

/** Profile is complete only when flag is set OR real setup fields exist (not auto signup name). */
function inferProfileComplete(array $row): bool {
    if (!empty($row['profile_complete'])) {
        return true;
    }
    $check = ['gender', 'birth_date', 'interests', 'phone', 'bio', 'profile_image', 'reason', 'goals'];
    foreach ($check as $field) {
        $val = trim((string)($row[$field] ?? ''));
        if ($val === '' || $val === '[]') {
            continue;
        }
        return true;
    }
    return false;
}

function syncProfileCompleteFlag(int $userId, array $row): bool {
    $complete = inferProfileComplete($row);
    if ($complete && empty($row['profile_complete'])) {
        db()->prepare('UPDATE users SET profile_complete = 1 WHERE id = ?')->execute([$userId]);
    }
    return $complete;
}

function profileRow(int $userId): array {
    $pdo = db();
    $st = $pdo->prepare(
        'SELECT u.id, u.email, u.name, u.profile_complete, u.created_at,
                p.bio, p.phone, p.gender, p.birth_date, p.interests, p.reason, p.goals, p.profile_image
         FROM users u
         LEFT JOIN user_profiles p ON p.user_id = u.id
         WHERE u.id = ? LIMIT 1'
    );
    $st->execute([$userId]);
    $row = $st->fetch();
    if (!$row) return [];

    $userId = (int)$row['id'];
    $complete = syncProfileCompleteFlag($userId, $row);

    $interests = [];
    if (!empty($row['interests'])) {
        $decoded = json_decode($row['interests'], true);
        $interests = is_array($decoded) ? $decoded : explode(',', $row['interests']);
    }

    return [
        'uid' => (string)$row['id'],
        'userName' => $row['name'] ?? '',
        'userBio' => $row['bio'] ?? '',
        'userEmail' => $row['email'] ?? '',
        'userPhone' => $row['phone'] ?? '',
        'gender' => $row['gender'] ?? '',
        'birthDate' => $row['birth_date'] ?? '',
        'interests' => $interests,
        'reason' => $row['reason'] ?? '',
        'goals' => $row['goals'] ?? '',
        'userImage' => imageUrl($row['profile_image'] ?? ''),
        'userImageBase64' => '',
        'profileComplete' => $complete,
    ];
}

function upsertProfile(int $userId, array $input): void {
    $pdo = db();
    $imagePath = null;
    if (!empty($input['userImageBase64'])) {
        $imagePath = saveBase64Image($input['userImageBase64'], 'profile', $userId);
    }

    $interests = $input['interests'] ?? [];
    if (is_array($interests)) {
        $interests = json_encode($interests);
    }

    $st = $pdo->prepare('SELECT user_id FROM user_profiles WHERE user_id = ?');
    $st->execute([$userId]);
    $exists = $st->fetch();

    if ($exists) {
        $sql = 'UPDATE user_profiles SET bio=?, phone=?, gender=?, birth_date=?, interests=?, reason=?, goals=?';
        $params = [
            trim($input['userBio'] ?? ''),
            trim($input['userPhone'] ?? ''),
            trim($input['gender'] ?? ''),
            trim($input['birthDate'] ?? ''),
            $interests,
            trim($input['reason'] ?? ''),
            trim($input['goals'] ?? ''),
        ];
        if ($imagePath) {
            $sql .= ', profile_image=?';
            $params[] = $imagePath;
        }
        $sql .= ' WHERE user_id=?';
        $params[] = $userId;
        $pdo->prepare($sql)->execute($params);
    } else {
        $pdo->prepare(
            'INSERT INTO user_profiles (user_id, bio, phone, gender, birth_date, interests, reason, goals, profile_image)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            $userId,
            trim($input['userBio'] ?? ''),
            trim($input['userPhone'] ?? ''),
            trim($input['gender'] ?? ''),
            trim($input['birthDate'] ?? ''),
            $interests,
            trim($input['reason'] ?? ''),
            trim($input['goals'] ?? ''),
            $imagePath ?? '',
        ]);
    }

    if (isset($input['userName']) && trim($input['userName']) !== '') {
        $pdo->prepare('UPDATE users SET name = ? WHERE id = ?')->execute([trim($input['userName']), $userId]);
    }
    if (isset($input['profileComplete'])) {
        $pdo->prepare('UPDATE users SET profile_complete = ? WHERE id = ?')->execute([
            $input['profileComplete'] ? 1 : 0,
            $userId,
        ]);
    }
}

function getAdminUserDetail(int $userId): array {
    $pdo = db();
    $st = $pdo->prepare('SELECT * FROM user_content WHERE user_id=? ORDER BY id DESC');
    $st->execute([$userId]);
    $content = $st->fetchAll();

    $st = $pdo->prepare('SELECT * FROM chat_sessions WHERE user_id=? ORDER BY updated_at DESC');
    $st->execute([$userId]);
    $chats = $st->fetchAll();
    foreach ($chats as &$chat) {
        $st2 = $pdo->prepare(
            'SELECT role, content, message_type, created_at FROM chat_messages
             WHERE user_id=? AND session_id=? ORDER BY id ASC'
        );
        $st2->execute([$userId, $chat['session_id']]);
        $chat['messages'] = $st2->fetchAll();
    }
    unset($chat);

    $st = $pdo->prepare('SELECT * FROM user_documents WHERE user_id=? ORDER BY uploaded_at DESC');
    $st->execute([$userId]);
    $documents = $st->fetchAll();
    foreach ($documents as &$doc) {
        if (!empty($doc['file_path'])) {
            $doc['file_url'] = imageUrl($doc['file_path']);
        }
        if (!empty($doc['extracted_text'])) {
            $doc['text_preview'] = mb_substr($doc['extracted_text'], 0, 300);
        }
    }
    unset($doc);

    $st = $pdo->prepare('SELECT * FROM user_progress WHERE user_id=?');
    $st->execute([$userId]);
    $progress = $st->fetch() ?: null;
    if ($progress && !empty($progress['weekly_data'])) {
        $progress['weekly_data'] = json_decode($progress['weekly_data'], true) ?: [];
    }

    return [
        'profile' => profileRow($userId),
        'content' => $content,
        'chats' => $chats,
        'documents' => $documents,
        'progress' => $progress,
    ];
}

function handleAdminApi(): void {
    header('Content-Type: application/json');
    if (!isAdminLoggedIn()) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Unauthorized']);
        return;
    }
    $method = $_SERVER['REQUEST_METHOD'];
    $input = getInput();
    $pdo = db();
    $sub = $_GET['sub'] ?? ($input['action'] ?? '');

    if ($method === 'GET' && $sub === 'get_user') {
        $email = trim($_GET['email'] ?? '');
        $st = $pdo->prepare(
            'SELECT u.id, u.email, u.name, u.profile_complete, u.created_at,
                    p.phone, p.gender, p.birth_date, p.interests, p.reason, p.goals, p.profile_image,
                    pr.current_streak, pr.best_streak, pr.total_activities
             FROM users u
             LEFT JOIN user_profiles p ON p.user_id = u.id
             LEFT JOIN user_progress pr ON pr.user_id = u.id
             WHERE u.email = ? LIMIT 1'
        );
        $st->execute([$email]);
        $user = $st->fetch();
        if ($user) {
            unset($user['password']);
            echo json_encode(['success' => true, 'user' => $user]);
        } else {
            echo json_encode(['success' => false, 'message' => 'User not found']);
        }
        return;
    }

    if ($method === 'GET' && $sub === 'user_detail') {
        $userId = (int)($_GET['user_id'] ?? 0);
        if (!$userId) {
            echo json_encode(['success' => false, 'message' => 'user_id required']);
            return;
        }
        echo json_encode(array_merge(['success' => true], getAdminUserDetail($userId)));
        return;
    }

    if ($method === 'POST') {
        switch ($sub) {
            case 'add_user':
                $name = trim($input['name'] ?? '');
                $email = trim($input['email'] ?? '');
                $password = trim($input['password'] ?? '');
                if (!$name || !$email || !$password) {
                    echo json_encode(['success' => false, 'message' => 'All fields are required']);
                    return;
                }
                $st = $pdo->prepare('SELECT id FROM users WHERE email = ?');
                $st->execute([$email]);
                if ($st->fetch()) {
                    echo json_encode(['success' => false, 'message' => 'Email already exists']);
                    return;
                }
                $pdo->prepare('INSERT INTO users (email, password, name, profile_complete) VALUES (?, ?, ?, 0)')
                    ->execute([$email, password_hash($password, PASSWORD_DEFAULT), $name]);
                $userId = (int)$pdo->lastInsertId();
                $pdo->prepare('INSERT INTO user_profiles (user_id) VALUES (?)')->execute([$userId]);
                $pdo->prepare('INSERT INTO user_progress (user_id) VALUES (?)')->execute([$userId]);
                echo json_encode(['success' => true, 'message' => 'User added successfully']);
                return;

            case 'update_user':
                $originalEmail = trim($input['original_email'] ?? '');
                $name = trim($input['name'] ?? '');
                $email = trim($input['email'] ?? '');
                $password = trim($input['password'] ?? '');
                if (!$originalEmail || !$name || !$email) {
                    echo json_encode(['success' => false, 'message' => 'All fields are required']);
                    return;
                }
                $st = $pdo->prepare('SELECT id FROM users WHERE email = ?');
                $st->execute([$originalEmail]);
                $row = $st->fetch();
                if (!$row) {
                    echo json_encode(['success' => false, 'message' => 'User not found']);
                    return;
                }
                if ($email !== $originalEmail) {
                    $st = $pdo->prepare('SELECT id FROM users WHERE email = ?');
                    $st->execute([$email]);
                    if ($st->fetch()) {
                        echo json_encode(['success' => false, 'message' => 'Email already exists']);
                        return;
                    }
                }
                if (!empty($password)) {
                    $pdo->prepare('UPDATE users SET name=?, email=?, password=? WHERE id=?')
                        ->execute([$name, $email, password_hash($password, PASSWORD_DEFAULT), $row['id']]);
                } else {
                    $pdo->prepare('UPDATE users SET name=?, email=? WHERE id=?')
                        ->execute([$name, $email, $row['id']]);
                }
                echo json_encode(['success' => true, 'message' => 'User updated successfully']);
                return;

            case 'delete_user':
                $userId = (int)($input['user_id'] ?? 0);
                $email = trim($input['email'] ?? '');
                try {
                    if ($userId <= 0 && $email !== '') {
                        $st = $pdo->prepare('SELECT id FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1');
                        $st->execute([$email]);
                        $row = $st->fetch();
                        if ($row) {
                            $userId = (int)$row['id'];
                        }
                    }
                    if ($userId <= 0) {
                        echo json_encode(['success' => false, 'message' => 'User not found']);
                        return;
                    }
                    if (deleteUserCompletely($pdo, $userId)) {
                        echo json_encode(['success' => true, 'message' => 'User deleted successfully']);
                    } else {
                        echo json_encode(['success' => false, 'message' => 'User not found']);
                    }
                } catch (Exception $e) {
                    echo json_encode(['success' => false, 'message' => 'Delete failed: ' . $e->getMessage()]);
                }
                return;

            case 'reset_profile':
                $email = trim($input['email'] ?? '');
                if (!$email) {
                    echo json_encode(['success' => false, 'message' => 'Email is required']);
                    return;
                }
                $st = $pdo->prepare('SELECT id FROM users WHERE email = ?');
                $st->execute([$email]);
                $row = $st->fetch();
                if (!$row) {
                    echo json_encode(['success' => false, 'message' => 'User not found']);
                    return;
                }
                $userId = (int)$row['id'];
                $pdo->prepare('UPDATE users SET profile_complete=0 WHERE id=?')->execute([$userId]);
                $pdo->prepare('DELETE FROM user_profiles WHERE user_id=?')->execute([$userId]);
                $pdo->prepare('INSERT INTO user_profiles (user_id) VALUES (?)')->execute([$userId]);
                echo json_encode(['success' => true, 'message' => 'Profile setup reset successfully']);
                return;
        }
    }
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
}


function renderAdminLogin($loginError = '') {
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Admin Login - NeuroNote</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
        <style>
            body {
                background: linear-gradient(135deg, #006D77 0%, #83C5BE 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            }
            .login-card {
                background: white;
                padding: 40px;
                border-radius: 20px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
                width: 100%;
                max-width: 400px;
            }
            .login-card .brand {
                text-align: center;
                margin-bottom: 30px;
            }
            .login-card .brand h2 {
                color: #006D77;
                font-weight: bold;
            }
            .login-card .brand span {
                color: #83C5BE;
            }
            .login-card .form-control {
                border-radius: 12px;
                padding: 12px 15px;
            }
            .login-card .btn-login {
                background: #006D77;
                color: white;
                border: none;
                padding: 12px;
                border-radius: 12px;
                width: 100%;
                font-weight: bold;
                transition: all 0.3s;
            }
            .login-card .btn-login:hover {
                background: #004d54;
            }
            .login-card .admin-badge {
                display: inline-block;
                background: #e8f5e9;
                color: #2e7d32;
                padding: 5px 15px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
            }
        </style>
    </head>
    <body>
        <div class="login-card">
            <div class="brand">
                <h2>Neuro<span>Note</span></h2>
                <span class="admin-badge"><i class="bi bi-shield-lock"></i> Admin Panel</span>
            </div>
            
            <?php if ($loginError): ?>
            <div class="alert alert-danger">
                <i class="bi bi-exclamation-triangle"></i> <?php echo $loginError; ?>
            </div>
            <?php endif; ?>
            
            <form method="POST">
                <div class="mb-3">
                    <label class="form-label">Email Address</label>
                    <div class="input-group">
                        <span class="input-group-text"><i class="bi bi-envelope"></i></span>
                        <input type="email" class="form-control" name="email" placeholder="admin@neuronote.com" required>
                    </div>
                </div>
                <div class="mb-3">
                    <label class="form-label">Password</label>
                    <div class="input-group">
                        <span class="input-group-text"><i class="bi bi-lock"></i></span>
                        <input type="password" class="form-control" name="password" placeholder="Enter password" required>
                    </div>
                </div>
                <button type="submit" name="login" class="btn-login">
                    <i class="bi bi-box-arrow-in-right"></i> Login
                </button>
            </form>
            
            <div class="mt-3 text-center text-muted small">
<i class="bi bi-info-circle"></i> Admin login credentials are configured securely.            </div>
        </div>
    </body>
    </html>
    <?php
}


function renderAdminDashboard() {
    $users = getMysqlUsers();
    
    $totalUsers = count($users);
    $newUsersToday = 0;
    $usersWithName = 0;
    $today = date('Y-m-d');
    
    foreach ($users as $user) {
        if (isset($user['created_at']) && strpos($user['created_at'], $today) === 0) {
            $newUsersToday++;
        }
        if (!empty($user['profile_complete'])) {
            $usersWithName++;
        }
    }
    
    $completionRate = $totalUsers > 0 ? round(($usersWithName / $totalUsers) * 100) : 0;
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>NeuroNote - Admin Dashboard</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <style>
            :root {
                --teal: #006D77;
                --teal-light: #83C5BE;
                --teal-dark: #004d54;
            }
            
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f4f6f9;
            }
            
            .sidebar {
                min-height: 100vh;
                background: var(--teal);
                color: white;
                padding: 20px;
                position: fixed;
                width: 250px;
                transition: all 0.3s;
            }
            
            .sidebar .brand {
                font-size: 24px;
                font-weight: bold;
                margin-bottom: 30px;
                padding: 10px;
                text-align: center;
            }
            
            .sidebar .brand span {
                color: var(--teal-light);
            }
            
            .sidebar .nav-item {
                padding: 12px 15px;
                margin: 5px 0;
                border-radius: 10px;
                cursor: pointer;
                transition: all 0.3s;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            
            .sidebar .nav-item:hover, .sidebar .nav-item.active {
                background: rgba(255, 255, 255, 0.2);
            }
            
            .sidebar .nav-item i {
                font-size: 20px;
            }
            
            .main-content {
                margin-left: 250px;
                padding: 20px;
            }
            
            .stat-card {
                background: white;
                padding: 20px;
                border-radius: 15px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                transition: transform 0.3s;
            }
            
            .stat-card:hover {
                transform: translateY(-5px);
            }
            
            .stat-card .stat-icon {
                font-size: 30px;
                color: var(--teal);
            }
            
            .stat-card .stat-number {
                font-size: 28px;
                font-weight: bold;
                color: var(--teal-dark);
            }
            
            .stat-card .stat-label {
                color: #666;
                font-size: 14px;
            }
            
            .table-container {
                background: white;
                border-radius: 15px;
                padding: 20px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                margin-top: 20px;
            }
            
            .table-container .table-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 20px;
                flex-wrap: wrap;
                gap: 10px;
            }
            
            .search-box {
                padding: 8px 15px;
                border: 2px solid #e0e0e0;
                border-radius: 25px;
                width: 300px;
                transition: all 0.3s;
            }
            
            .search-box:focus {
                border-color: var(--teal);
                outline: none;
            }
            
            .status-badge {
                padding: 5px 12px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
            }
            
            .status-active {
                background: #d4edda;
                color: #155724;
            }
            
            .btn-teal {
                background: var(--teal);
                color: white;
                border: none;
                padding: 8px 20px;
                border-radius: 8px;
                transition: all 0.3s;
            }
            
            .btn-teal:hover {
                background: var(--teal-dark);
                color: white;
            }
            
            .btn-outline-teal {
                border: 2px solid var(--teal);
                color: var(--teal);
                background: transparent;
                padding: 6px 15px;
                border-radius: 8px;
                transition: all 0.3s;
            }
            
            .btn-outline-teal:hover {
                background: var(--teal);
                color: white;
            }
            
            .modal-content {
                border-radius: 15px;
            }
            
            .modal-header {
                background: var(--teal);
                color: white;
                border-radius: 15px 15px 0 0;
            }
            
            .modal-header .btn-close {
                filter: brightness(0) invert(1);
            }
            
            .avatar-circle {
                width: 40px;
                height: 40px;
                border-radius: 50%;
                background: var(--teal-light);
                color: white;
                display: flex;
                align-items: center;
                justify-content: center;
                font-weight: bold;
            }
            
            .empty-state {
                text-align: center;
                padding: 40px;
                color: #999;
            }
            
            .empty-state i {
                font-size: 60px;
                margin-bottom: 15px;
            }

            .detail-section {
                margin-bottom: 1.25rem;
            }

            .detail-section h6 {
                color: var(--teal);
                font-weight: 700;
                border-bottom: 2px solid var(--teal-light);
                padding-bottom: 6px;
                margin-bottom: 10px;
            }

            .chat-bubble {
                padding: 8px 12px;
                border-radius: 12px;
                margin-bottom: 8px;
                font-size: 13px;
            }

            .chat-user { background: #e8f5f3; }
            .chat-ai { background: #f1f3f5; }

            .count-badge {
                display: inline-block;
                background: #e8f5f3;
                color: var(--teal-dark);
                padding: 2px 8px;
                border-radius: 10px;
                font-size: 11px;
                margin: 2px;
            }
            
            @media (max-width: 768px) {
                .sidebar {
                    position: relative;
                    width: 100%;
                    min-height: auto;
                }
                .main-content {
                    margin-left: 0;
                }
                .search-box {
                    width: 100%;
                }
            }
        </style>
    </head>
    <body>
        <!-- Sidebar -->
        <div class="sidebar">
            <div class="brand">
                Neuro<span>Note</span>
                <small style="display:block; font-size:12px; opacity:0.7;">Admin Panel</small>
            </div>
            <nav>
                <div class="nav-item active">
                    <i class="bi bi-speedometer2"></i>
                    <span>Dashboard</span>
                </div>
                <div class="nav-item" onclick="location.reload()">
                    <i class="bi bi-people"></i>
                    <span>Users</span>
                </div>
                <div class="nav-item" onclick="exportData()">
                    <i class="bi bi-download"></i>
                    <span>Export Data</span>
                </div>
                <div class="nav-item" style="margin-top: 50px;" onclick="logout()">
                    <i class="bi bi-box-arrow-right"></i>
                    <span>Logout</span>
                </div>
            </nav>
        </div>

        <!-- Main Content -->
        <div class="main-content">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h2>Dashboard</h2>
                <div>
                    <span class="me-3">Welcome, <?php echo $_SESSION['admin_name'] ?? 'Admin'; ?></span>
                    <button class="btn btn-outline-teal" onclick="logout()">
                        <i class="bi bi-box-arrow-right"></i> Logout
                    </button>
                </div>
            </div>

            <!-- Statistics Cards -->
            <div class="row g-4 mb-4">
                <div class="col-md-3">
                    <div class="stat-card">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <div class="stat-number"><?php echo $totalUsers; ?></div>
                                <div class="stat-label">Total Users</div>
                            </div>
                            <div class="stat-icon">
                                <i class="bi bi-people"></i>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="stat-card">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <div class="stat-number"><?php echo $newUsersToday; ?></div>
                                <div class="stat-label">New Users Today</div>
                            </div>
                            <div class="stat-icon">
                                <i class="bi bi-person-plus"></i>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="stat-card">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <div class="stat-number"><?php echo $usersWithName; ?></div>
                                <div class="stat-label">Profiles Completed</div>
                            </div>
                            <div class="stat-icon">
                                <i class="bi bi-check-circle"></i>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="stat-card">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <div class="stat-number"><?php echo $completionRate; ?>%</div>
                                <div class="stat-label">Completion Rate</div>
                            </div>
                            <div class="stat-icon">
                                <i class="bi bi-percent"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Users Table -->
            <div class="table-container">
                <div class="table-header">
                    <h5><i class="bi bi-people me-2"></i>All Users</h5>
                    <div class="d-flex gap-2">
                        <input type="text" class="search-box" id="searchUser" placeholder="Search users..." onkeyup="searchUsers()">
                        <button class="btn btn-teal" onclick="showAddUserModal()">
                            <i class="bi bi-person-plus"></i> Add User
                        </button>
                    </div>
                </div>
                <div class="table-responsive">
                    <?php if (empty($users)): ?>
                    <div class="empty-state">
                        <i class="bi bi-inbox"></i>
                        <h5>No users found</h5>
                        <p class="text-muted">Users will appear here once they sign up.</p>
                    </div>
                    <?php else: ?>
                    <table class="table table-hover" id="usersTable">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>User</th>
                                <th>Email</th>
                                <th>Activity</th>
                                <th>Joined</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php $index = 1; foreach ($users as $user): ?>
                            <tr>
                                <td><?php echo $index++; ?></td>
                                <td>
                                    <div class="d-flex align-items-center gap-2">
                                        <?php if (!empty($user['profile_image_url'])): ?>
                                        <img src="<?php echo htmlspecialchars($user['profile_image_url']); ?>" class="avatar-circle" style="object-fit:cover;width:40px;height:40px;" alt="">
                                        <?php else: ?>
                                        <div class="avatar-circle">
                                            <?php echo strtoupper(substr($user['name'] ?? 'U', 0, 1)); ?>
                                        </div>
                                        <?php endif; ?>
                                        <div>
                                            <div class="fw-bold"><?php echo htmlspecialchars($user['name'] ?? 'No Name'); ?></div>
                                            <small class="text-muted">ID: #<?php echo (int)$user['id']; ?></small>
                                            <?php
                                            $meta = [];
                                            if (!empty($user['phone'])) $meta[] = 'Phone: ' . $user['phone'];
                                            if (!empty($user['gender'])) $meta[] = 'Gender: ' . $user['gender'];
                                            if (!empty($user['birth_date'])) $meta[] = 'DOB: ' . $user['birth_date'];
                                            if (!empty($user['interests'])) $meta[] = 'Interests: ' . $user['interests'];
                                            if (!empty($user['goals'])) $meta[] = 'Goals: ' . $user['goals'];
                                            if (!empty($meta)):
                                            ?>
                                            <div><small class="text-muted"><?php echo htmlspecialchars(implode(' • ', $meta)); ?></small></div>
                                            <?php endif; ?>
                                        </div>
                                    </div>
                                </td>
                                <td><?php echo htmlspecialchars($user['email']); ?></td>
                                <td>
                                    <span class="count-badge">FC: <?php echo (int)($user['flashcard_count'] ?? 0); ?></span>
                                    <span class="count-badge">Quiz: <?php echo (int)($user['quiz_count'] ?? 0); ?></span>
                                    <span class="count-badge">Sum: <?php echo (int)($user['summary_count'] ?? 0); ?></span>
                                    <span class="count-badge">Audio: <?php echo (int)($user['audio_count'] ?? 0); ?></span>
                                    <span class="count-badge">Chats: <?php echo (int)($user['chat_count'] ?? 0); ?></span>
                                    <span class="count-badge">Docs: <?php echo (int)($user['document_count'] ?? 0); ?></span>
                                    <span class="count-badge">Streak: <?php echo (int)($user['current_streak'] ?? 0); ?></span>
                                </td>
                                <td><?php echo isset($user['created_at']) ? date('M d, Y', strtotime($user['created_at'])) : 'N/A'; ?></td>
                                <td>
                                    <?php if (!empty($user['profile_complete'])): ?>
                                    <span class="status-badge status-active">Profile Complete</span>
                                    <?php else: ?>
                                    <span class="status-badge" style="background:#fff3cd;color:#856404;">Setup Pending</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                     <button class="btn btn-sm btn-teal me-1" onclick="viewUserDetail(<?php echo (int)$user['id']; ?>)" title="View all data">
                                         <i class="bi bi-eye"></i>
                                     </button>
                                     <button class="btn btn-sm btn-outline-teal me-1" onclick="editUser('<?php echo $user['email']; ?>')" title="Edit User">
                                         <i class="bi bi-pencil"></i>
                                     </button>
                                     <button class="btn btn-sm btn-outline-warning me-1" onclick="resetProfile('<?php echo $user['email']; ?>')" title="Reset Profile Setup">
                                         <i class="bi bi-arrow-counterclockwise"></i>
                                     </button>
                                     <button class="btn btn-sm btn-outline-danger" onclick="deleteUser(<?php echo (int)$user['id']; ?>)" title="Delete User">
                                         <i class="bi bi-trash"></i>
                                     </button>
                                 </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <!-- User Full Detail Modal -->
        <div class="modal fade" id="userDetailModal" tabindex="-1">
            <div class="modal-dialog modal-xl modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="userDetailTitle">User Details</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body" id="userDetailBody">
                        <div class="text-center py-4 text-muted">Loading...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Add/Edit User Modal -->
        <div class="modal fade" id="userModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="userModalTitle">Add New User</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="userForm">
                            <input type="hidden" id="userEmailOriginal" name="userEmailOriginal">
                            <div class="mb-3">
                                <label class="form-label">Full Name</label>
                                <input type="text" class="form-control" id="userName" name="name" required>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Email</label>
                                <input type="email" class="form-control" id="userEmail" name="email" required>
                            </div>
                            <div class="mb-3" id="passwordField">
                                <label class="form-label">Password</label>
                                <input type="password" class="form-control" id="userPassword" name="password" placeholder="Leave blank to keep current password">
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        <button type="button" class="btn btn-teal" onclick="saveUser()">Save User</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Delete Confirmation Modal -->
        <div class="modal fade" id="deleteModal" tabindex="-1">
            <div class="modal-dialog modal-sm">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Confirm Delete</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <p>Are you sure you want to delete this user?</p>
                        <p class="text-danger"><small>This action cannot be undone!</small></p>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        <button type="button" class="btn btn-danger" onclick="confirmDelete()">Delete</button>
                    </div>
                </div>
            </div>
        </div>

        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
        <script>
            let deleteUserId = null;
            let userModal = new bootstrap.Modal(document.getElementById('userModal'));
            let deleteModal = new bootstrap.Modal(document.getElementById('deleteModal'));
            let userDetailModal = new bootstrap.Modal(document.getElementById('userDetailModal'));

            function escHtml(s) {
                if (!s) return '';
                return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
            }

            function viewUserDetail(userId) {
                document.getElementById('userDetailTitle').textContent = 'User #' + userId + ' — Full Activity';
                document.getElementById('userDetailBody').innerHTML = '<div class="text-center py-4"><div class="spinner-border text-teal"></div></div>';
                userDetailModal.show();

                $.get('dashboard9.php?action=admin_api&sub=user_detail&user_id=' + userId, function(res) {
                    let data = typeof res === 'string' ? JSON.parse(res) : res;
                    if (!data.success) {
                        document.getElementById('userDetailBody').innerHTML = '<div class="alert alert-danger">' + escHtml(data.message || 'Failed to load') + '</div>';
                        return;
                    }

                    const p = data.profile || {};
                    let html = '<div class="detail-section"><h6><i class="bi bi-person"></i> Profile</h6>';
                    html += '<div class="row g-2 small">';
                    html += '<div class="col-md-6"><strong>Name:</strong> ' + escHtml(p.userName) + '</div>';
                    html += '<div class="col-md-6"><strong>Email:</strong> ' + escHtml(p.userEmail) + '</div>';
                    html += '<div class="col-md-6"><strong>Phone:</strong> ' + escHtml(p.userPhone) + '</div>';
                    html += '<div class="col-md-6"><strong>Gender:</strong> ' + escHtml(p.gender) + '</div>';
                    html += '<div class="col-md-6"><strong>DOB:</strong> ' + escHtml(p.birthDate) + '</div>';
                    html += '<div class="col-md-6"><strong>Bio:</strong> ' + escHtml(p.userBio) + '</div>';
                    html += '<div class="col-md-6"><strong>Reason:</strong> ' + escHtml(p.reason) + '</div>';
                    html += '<div class="col-md-6"><strong>Goals:</strong> ' + escHtml(p.goals) + '</div>';
                    if (p.interests && p.interests.length) {
                        html += '<div class="col-12"><strong>Interests:</strong> ' + escHtml(p.interests.join(', ')) + '</div>';
                    }
                    if (p.userImage) {
                        html += '<div class="col-12"><strong>Photo:</strong><br><img src="' + escHtml(p.userImage) + '" style="max-width:120px;border-radius:12px;margin-top:6px;"></div>';
                    }
                    html += '</div></div>';

                    const prog = data.progress;
                    html += '<div class="detail-section"><h6><i class="bi bi-graph-up"></i> Progress & Streak</h6>';
                    if (prog) {
                        html += '<p class="small mb-1">Current streak: <strong>' + (prog.current_streak || 0) + '</strong> | Best: <strong>' + (prog.best_streak || 0) + '</strong> | Activities: <strong>' + (prog.total_activities || 0) + '</strong></p>';
                        if (prog.weekly_data && prog.weekly_data.length) {
                            html += '<p class="small text-muted">Weekly: ' + prog.weekly_data.join(', ') + '</p>';
                        }
                    } else {
                        html += '<p class="text-muted small">No progress data yet.</p>';
                    }
                    html += '</div>';

                    html += '<div class="detail-section"><h6><i class="bi bi-collection"></i> AI Content (' + (data.content || []).length + ')</h6>';
                    if (!data.content || !data.content.length) {
                        html += '<p class="text-muted small">No flashcards, quizzes, summaries or audio notes.</p>';
                    } else {
                        html += '<div class="table-responsive"><table class="table table-sm table-bordered"><thead><tr><th>Type</th><th>Title</th><th>Action</th><th>Date</th></tr></thead><tbody>';
                        data.content.forEach(function(c) {
                            html += '<tr><td>' + escHtml(c.content_type) + '</td><td>' + escHtml(c.title) + '</td><td>' + escHtml(c.action) + '</td><td>' + escHtml(c.item_date || c.created_at) + '</td></tr>';
                        });
                        html += '</tbody></table></div>';
                    }
                    html += '</div>';

                    html += '<div class="detail-section"><h6><i class="bi bi-chat-dots"></i> Chats (' + (data.chats || []).length + ')</h6>';
                    if (!data.chats || !data.chats.length) {
                        html += '<p class="text-muted small">No chat history.</p>';
                    } else {
                        data.chats.forEach(function(chat) {
                            html += '<div class="border rounded p-2 mb-2"><div class="fw-bold small">' + escHtml(chat.title || 'Chat') + ' <span class="text-muted">(' + (chat.message_count || 0) + ' msgs)</span></div>';
                            if (chat.messages && chat.messages.length) {
                                chat.messages.forEach(function(m) {
                                    const cls = m.role === 'user' ? 'chat-user' : 'chat-ai';
                                    html += '<div class="chat-bubble ' + cls + '"><strong>' + escHtml(m.role) + ':</strong> ' + escHtml((m.content || '').substring(0, 500)) + '</div>';
                                });
                            }
                            html += '</div>';
                        });
                    }
                    html += '</div>';

                    html += '<div class="detail-section"><h6><i class="bi bi-file-earmark"></i> Documents (' + (data.documents || []).length + ')</h6>';
                    if (!data.documents || !data.documents.length) {
                        html += '<p class="text-muted small">No uploaded documents.</p>';
                    } else {
                        data.documents.forEach(function(doc) {
                            html += '<div class="border rounded p-2 mb-2 small">';
                            html += '<div><strong>' + escHtml(doc.file_name) + '</strong> <span class="text-muted">(' + escHtml(doc.file_type) + ')</span></div>';
                            html += '<div class="text-muted">' + escHtml(doc.uploaded_at) + '</div>';
                            if (doc.text_preview) {
                                html += '<div class="mt-1">' + escHtml(doc.text_preview) + '...</div>';
                            }
                            html += '</div>';
                        });
                    }
                    html += '</div>';

                    document.getElementById('userDetailBody').innerHTML = html;
                }).fail(function() {
                    document.getElementById('userDetailBody').innerHTML = '<div class="alert alert-danger">Error loading user details.</div>';
                });
            }

            function searchUsers() {
                let input = document.getElementById('searchUser');
                let filter = input.value.toUpperCase();
                let table = document.getElementById('usersTable');
                if (!table) return;
                let rows = table.getElementsByTagName('tr');

                for (let i = 1; i < rows.length; i++) {
                    let cells = rows[i].getElementsByTagName('td');
                    let found = false;
                    for (let j = 0; j < cells.length; j++) {
                        if (cells[j]) {
                            let text = cells[j].textContent || cells[j].innerText;
                            if (text.toUpperCase().indexOf(filter) > -1) {
                                found = true;
                                break;
                            }
                        }
                    }
                    rows[i].style.display = found ? '' : 'none';
                }
            }

            function showAddUserModal() {
                document.getElementById('userModalTitle').textContent = 'Add New User';
                document.getElementById('userEmailOriginal').value = '';
                document.getElementById('userName').value = '';
                document.getElementById('userEmail').value = '';
                document.getElementById('userPassword').value = '';
                document.getElementById('passwordField').style.display = 'block';
                document.getElementById('userPassword').placeholder = 'Enter password';
                userModal.show();
            }

            function editUser(email) {
                $.ajax({
                    url: 'dashboard9.php?action=admin_api&sub=get_user',
                    type: 'GET',
                    data: { sub: 'get_user', email: email },
                    success: function(response) {
                        let data = JSON.parse(response);
                        if (data.success) {
                            document.getElementById('userModalTitle').textContent = 'Edit User';
                            document.getElementById('userEmailOriginal').value = data.user.email;
                            document.getElementById('userName').value = data.user.name || '';
                            document.getElementById('userEmail').value = data.user.email;
                            document.getElementById('userPassword').value = '';
                            document.getElementById('passwordField').style.display = 'block';
                            document.getElementById('userPassword').placeholder = 'Leave blank to keep current password';
                            userModal.show();
                        } else {
                            alert(data.message || 'Error loading user data');
                        }
                    },
                    error: function() {
                        alert('Error loading user data');
                    }
                });
            }

            function saveUser() {
                let originalEmail = document.getElementById('userEmailOriginal').value;
                let name = document.getElementById('userName').value;
                let email = document.getElementById('userEmail').value;
                let password = document.getElementById('userPassword').value;

                if (!name || !email) {
                    alert('Please fill all required fields');
                    return;
                }

                let data = {
                    action: originalEmail ? 'update_user' : 'add_user',
                    original_email: originalEmail,
                    name: name,
                    email: email,
                    password: password
                };

                $.ajax({
                    url: 'dashboard9.php?action=admin_api',
                    type: 'POST',
                    data: JSON.stringify(data),
                    contentType: 'application/json',
                    success: function(response) {
                        let result = JSON.parse(response);
                        if (result.success) {
                            userModal.hide();
                            location.reload();
                        } else {
                            alert(result.message || 'Error saving user');
                        }
                    },
                    error: function() {
                        alert('Error saving user');
                    }
                });
            }

            function deleteUser(userId) {
                deleteUserId = userId;
                deleteModal.show();
            }

            function confirmDelete() {
                if (!deleteUserId) return;
                $.ajax({
                    url: 'dashboard9.php?action=admin_api',
                    type: 'POST',
                    data: JSON.stringify({
                        action: 'delete_user',
                        user_id: deleteUserId
                    }),
                    contentType: 'application/json',
                    dataType: 'json',
                    success: function(result) {
                        if (result.success) {
                            deleteModal.hide();
                            location.reload();
                        } else {
                            alert(result.message || 'Error deleting user');
                        }
                    },
                    error: function(xhr) {
                        let msg = 'Error deleting user';
                        try {
                            const result = JSON.parse(xhr.responseText || '{}');
                            if (result.message) msg = result.message;
                        } catch (e) {}
                        alert(msg);
                    }
                });
            }

            function resetProfile(email) {
                if (confirm('Are you sure you want to reset this user\'s profile setup data? They will have to complete the setup flow again.')) {
                    $.ajax({
                        url: 'dashboard9.php?action=admin_api',
                        type: 'POST',
                        data: JSON.stringify({
                            action: 'reset_profile',
                            email: email
                        }),
                        contentType: 'application/json',
                        success: function(response) {
                            let result = JSON.parse(response);
                            if (result.success) {
                                alert('Profile setup reset successfully!');
                                location.reload();
                            } else {
                                alert(result.message || 'Error resetting profile');
                            }
                        },
                        error: function() {
                            alert('Error resetting profile');
                        }
                    });
                }
            }

            function exportData() {
                window.location.href = 'dashboard9.php?action=admin_export';
            }

            function logout() {
                if (confirm('Are you sure you want to logout?')) {
                    window.location.href = 'dashboard9.php?action=admin_logout';
                }
            }
        </script>
    </body>
    </html>
    <?php
}



// ─── ADMIN PANEL ROUTING ───────────────────────────────────────
$action = $_GET['action'] ?? '';

if ($action === 'serve_file') {
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, OPTIONS');
        http_response_code(200);
        exit;
    }
    serveUploadFile($_GET['path'] ?? '');
}

if ($action === 'admin_logout') {
    session_destroy();
    header('Location: ' . SELF_FILE . '?action=admin');
    exit;
}

if ($action === 'admin_export') {
    if (!isAdminLoggedIn()) {
        header('Location: ' . SELF_FILE . '?action=admin');
        exit;
    }
    $users = getMysqlUsers();
    header('Content-Type: application/json');
    header('Content-Disposition: attachment; filename="users_export_' . date('Y-m-d') . '.json"');
    echo json_encode($users, JSON_PRETTY_PRINT);
    exit;
}

if ($action === 'admin_api') {
    handleAdminApi();
    exit;
}

if ($action === '' || $action === 'admin') {
    $loginError = '';
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
        $email = $_POST['email'] ?? '';
        $password = $_POST['password'] ?? '';
        if ($email === ADMIN_EMAIL && $password === ADMIN_PASSWORD) {
            $_SESSION['admin_logged_in'] = true;
            $_SESSION['admin_email'] = $email;
            $_SESSION['admin_name'] = 'Admin';
            header('Location: ' . SELF_FILE . '?action=admin');
            exit;
        }
        $loginError = 'Invalid email or password';
    }
    if (!isAdminLoggedIn()) {
        renderAdminLogin($loginError);
    } else {
        renderAdminDashboard();
    }
    exit;
}

// ─── App API (JSON) ────────────────────────────────────────────
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$input = getInput();

try {
    switch ($action) {



    case 'ping':
        jsonOut(['success' => true, 'message' => 'Server is online']);

    // ─── AUTH ──────────────────────────────────────────────────
    case 'signup':
        $email = trim($input['email'] ?? '');
        $password = trim($input['password'] ?? '');
        if (!$email || !$password) {
            jsonOut(['success' => false, 'message' => 'Email and password are required']);
        }
        $pdo = db();
        $st = $pdo->prepare('SELECT id FROM users WHERE email = ?');
        $st->execute([$email]);
        if ($st->fetch()) {
            jsonOut(['success' => false, 'message' => 'Email already exists']);
        }
        $name = explode('@', $email)[0];
        $pdo->prepare('INSERT INTO users (email, password, name, profile_complete) VALUES (?, ?, ?, 0)')
            ->execute([$email, password_hash($password, PASSWORD_DEFAULT), $name]);
        $userId = (int)$pdo->lastInsertId();
        $pdo->prepare('INSERT INTO user_profiles (user_id) VALUES (?)')->execute([$userId]);
        $pdo->prepare('INSERT INTO user_progress (user_id) VALUES (?)')->execute([$userId]);
        jsonOut(['success' => true, 'message' => 'Account created successfully', 'uid' => (string)$userId]);

    case 'login':
        $email = trim($input['email'] ?? '');
        $password = trim($input['password'] ?? '');
        $pdo = db();
        $st = $pdo->prepare('SELECT * FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1');
        $st->execute([$email]);
        $user = $st->fetch();
        if ($user && password_verify($password, $user['password'])) {
            $profile = profileRow((int)$user['id']);
            jsonOut([
                'success' => true,
                'message' => 'Login successful',
                'uid' => (string)$user['id'],
                'name' => $user['name'] ?? explode('@', $email)[0],
                'email' => $user['email'],
                'profileComplete' => $profile['profileComplete'] ?? false,
            ]);
        }
        jsonOut(['success' => false, 'message' => 'Invalid email or password']);

    case 'save_profile':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        upsertProfile($userId, $input);
        if (!empty($input['profileComplete'])) {
            db()->prepare('UPDATE users SET profile_complete = 1 WHERE id = ?')->execute([$userId]);
        }
        jsonOut(['success' => true, 'message' => 'Profile saved successfully', 'profile' => profileRow($userId)]);

    case 'get_profile':
        $userId = findUserId($input['uid'] ?? $_GET['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        jsonOut(['success' => true, 'profile' => profileRow($userId)]);

    case 'upload_profile_image':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $path = saveBase64Image($input['userImageBase64'] ?? '', 'profile', $userId);
        if (!$path) jsonOut(['success' => false, 'message' => 'Invalid image data']);
        db()->prepare('UPDATE user_profiles SET profile_image = ? WHERE user_id = ?')->execute([$path, $userId]);
        jsonOut(['success' => true, 'userImage' => imageUrl($path)]);

    case 'forgot_password':
        $email = trim($input['email'] ?? '');
        $st = db()->prepare('SELECT id FROM users WHERE email = ?');
        $st->execute([$email]);
        $found = (bool)$st->fetch();
        jsonOut(['success' => $found, 'message' => $found ? 'Email verified' : 'Email not found']);

    case 'reset_password':
        $email = trim($input['email'] ?? '');
        $newPassword = trim($input['new_password'] ?? '');
        if (!$email || !$newPassword || strlen($newPassword) < 6) {
            jsonOut(['success' => false, 'message' => 'Invalid email or password']);
        }
        $st = db()->prepare('UPDATE users SET password = ? WHERE email = ?');
        $st->execute([password_hash($newPassword, PASSWORD_DEFAULT), $email]);
        jsonOut(['success' => $st->rowCount() > 0, 'message' => $st->rowCount() ? 'Password changed successfully' : 'Email not found']);

    case 'change_password':
        $email = trim($input['email'] ?? '');
        $current = trim($input['current_password'] ?? '');
        $newPassword = trim($input['new_password'] ?? '');
        $st = db()->prepare('SELECT password FROM users WHERE email = ?');
        $st->execute([$email]);
        $user = $st->fetch();
        if (!$user || !password_verify($current, $user['password'])) {
            jsonOut(['success' => false, 'message' => 'Current password is incorrect']);
        }
        db()->prepare('UPDATE users SET password = ? WHERE email = ?')
            ->execute([password_hash($newPassword, PASSWORD_DEFAULT), $email]);
        jsonOut(['success' => true, 'message' => 'Password changed successfully']);

    // ─── CONTENT ───────────────────────────────────────────────
    case 'save_content':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $type = trim($input['type'] ?? '');
        $itemId = trim($input['id'] ?? '');
        if (!$type || !$itemId) jsonOut(['success' => false, 'message' => 'type and id are required']);

        $skip = ['email', 'uid', 'type', 'id', 'title', 'content', 'action', 'timestamp', 'date'];
        $extra = [];
        foreach ($input as $k => $v) {
            if (!in_array($k, $skip, true)) $extra[$k] = $v;
        }

        $pdo = db();
        $pdo->prepare(
            'DELETE FROM user_content WHERE user_id=? AND content_type=? AND item_id=?'
        )->execute([$userId, $type, $itemId]);
        $pdo->prepare(
            'INSERT INTO user_content (user_id, content_type, item_id, title, content, action, extra_json, item_date, item_timestamp)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            $userId, $type, $itemId,
            trim($input['title'] ?? ''),
            is_string($input['content'] ?? '') ? $input['content'] : json_encode($input['content'] ?? ''),
            trim($input['action'] ?? ''),
            json_encode($extra),
            trim($input['date'] ?? ''),
            trim($input['timestamp'] ?? ''),
        ]);
        jsonOut(['success' => true, 'message' => 'Content saved']);

    case 'get_content':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $st = db()->prepare('SELECT * FROM user_content WHERE user_id = ? ORDER BY id DESC');
        $st->execute([$userId]);
        $rows = $st->fetchAll();
        $data = ['flashcards' => [], 'quizzes' => [], 'summaries' => [], 'audio_notes' => []];
        foreach ($rows as $row) {
            $item = [
                'id' => $row['item_id'],
                'title' => $row['title'],
                'content' => $row['content'],
                'action' => $row['action'],
                'date' => $row['item_date'],
                'timestamp' => $row['item_timestamp'],
            ];
            if (!empty($row['extra_json'])) {
                $extra = json_decode($row['extra_json'], true);
                if (is_array($extra)) $item = array_merge($item, $extra);
            }
            $key = $row['content_type'];
            if (isset($data[$key])) $data[$key][] = $item;
        }
        jsonOut(['success' => true, 'data' => $data]);

    case 'delete_content':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        db()->prepare('DELETE FROM user_content WHERE user_id=? AND content_type=? AND item_id=?')
            ->execute([$userId, trim($input['type'] ?? ''), trim($input['id'] ?? '')]);
        jsonOut(['success' => true, 'message' => 'Content deleted']);

    case 'save_progress':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $weekly = $input['weekly_data'] ?? [];
        db()->prepare(
            'INSERT INTO user_progress (user_id, current_streak, best_streak, last_active_date, total_activities, weekly_data, week_start)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE current_streak=VALUES(current_streak), best_streak=VALUES(best_streak),
             last_active_date=VALUES(last_active_date), total_activities=VALUES(total_activities),
             weekly_data=VALUES(weekly_data), week_start=VALUES(week_start)'
        )->execute([
            $userId,
            (int)($input['current_streak'] ?? 0),
            (int)($input['best_streak'] ?? 0),
            trim($input['last_active_date'] ?? ''),
            (int)($input['total_activities'] ?? 0),
            json_encode($weekly),
            trim($input['week_start'] ?? ''),
        ]);
        jsonOut(['success' => true, 'message' => 'Progress saved']);

    case 'get_progress':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $st = db()->prepare('SELECT * FROM user_progress WHERE user_id = ?');
        $st->execute([$userId]);
        $row = $st->fetch();
        if (!$row) jsonOut(['success' => true, 'progress' => null]);
        $row['weekly_data'] = json_decode($row['weekly_data'] ?? '[]', true) ?: [];
        jsonOut(['success' => true, 'progress' => $row]);

    case 'get_stats':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $pdo = db();
        $counts = ['flashcards' => 0, 'quizzes' => 0, 'summaries' => 0, 'audio_notes' => 0];
        $st = $pdo->prepare('SELECT content_type, COUNT(*) as c FROM user_content WHERE user_id=? GROUP BY content_type');
        $st->execute([$userId]);
        foreach ($st->fetchAll() as $r) {
            $counts[$r['content_type']] = (int)$r['c'];
        }
        $st = $pdo->prepare('SELECT * FROM user_progress WHERE user_id=?');
        $st->execute([$userId]);
        $p = $st->fetch() ?: [];
        $weekly = json_decode($p['weekly_data'] ?? '[]', true) ?: [];
        jsonOut([
            'success' => true,
            'stats' => [
                'flashcard_count' => $counts['flashcards'],
                'quiz_count' => $counts['quizzes'],
                'summary_count' => $counts['summaries'],
                'audio_count' => $counts['audio_notes'],
                'total_items' => array_sum($counts),
                'current_streak' => (int)($p['current_streak'] ?? 0),
                'best_streak' => (int)($p['best_streak'] ?? 0),
                'total_activities' => (int)($p['total_activities'] ?? 0),
                'weekly_data' => $weekly,
                'week_start' => $p['week_start'] ?? '',
                'last_active_date' => $p['last_active_date'] ?? '',
            ],
        ]);

    // ─── CHAT ──────────────────────────────────────────────────
    case 'save_chat':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $sessionId = trim($input['session_id'] ?? '');
        $title = trim($input['title'] ?? 'Chat');
        $messages = $input['messages'] ?? [];
        if (!$sessionId) jsonOut(['success' => false, 'message' => 'session_id required']);

        $pdo = db();
        $pdo->prepare(
            'INSERT INTO chat_sessions (user_id, session_id, title, message_count)
             VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE title=VALUES(title), message_count=VALUES(message_count), updated_at=NOW()'
        )->execute([$userId, $sessionId, $title, count($messages)]);

        $pdo->prepare('DELETE FROM chat_messages WHERE user_id=? AND session_id=?')->execute([$userId, $sessionId]);
        $ins = $pdo->prepare(
            'INSERT INTO chat_messages (user_id, session_id, role, content, message_type, extra_json) VALUES (?, ?, ?, ?, ?, ?)'
        );
        foreach ($messages as $msg) {
            $ins->execute([
                $userId,
                $sessionId,
                ($msg['isUser'] ?? false) ? 'user' : 'assistant',
                $msg['text'] ?? '',
                $msg['type'] ?? 'text',
                json_encode($msg),
            ]);
        }
        jsonOut(['success' => true, 'message' => 'Chat saved']);

    case 'get_chats':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $pdo = db();
        $st = $pdo->prepare('SELECT * FROM chat_sessions WHERE user_id=? ORDER BY updated_at DESC');
        $st->execute([$userId]);
        $chats = $st->fetchAll();
        foreach ($chats as &$chat) {
            $st2 = $pdo->prepare(
                'SELECT role, content, message_type, extra_json, created_at
                 FROM chat_messages WHERE user_id=? AND session_id=? ORDER BY id ASC'
            );
            $st2->execute([$userId, $chat['session_id']]);
            $messages = [];
            foreach ($st2->fetchAll() as $row) {
                if (!empty($row['extra_json'])) {
                    $extra = json_decode($row['extra_json'], true);
                    if (is_array($extra)) {
                        $messages[] = $extra;
                        continue;
                    }
                }
                $messages[] = [
                    'text' => $row['content'] ?? '',
                    'isUser' => ($row['role'] ?? '') === 'user',
                    'timestamp' => $row['created_at'] ?? '',
                ];
            }
            $chat['messages'] = $messages;
        }
        unset($chat);
        jsonOut(['success' => true, 'chats' => $chats]);

    // ─── DOCUMENTS ─────────────────────────────────────────────
    case 'save_document':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $fileName = trim($input['file_name'] ?? '');
        $fileType = trim($input['file_type'] ?? '');
        $text = $input['extracted_text'] ?? '';
        $filePath = null;
        if (!empty($input['file_base64'])) {
            $filePath = saveBase64Image($input['file_base64'], 'doc', $userId);
        }
        db()->prepare(
            'INSERT INTO user_documents (user_id, file_name, file_type, file_path, extracted_text) VALUES (?, ?, ?, ?, ?)'
        )->execute([$userId, $fileName, $fileType, $filePath ?? '', $text]);
        jsonOut(['success' => true, 'message' => 'Document saved']);

    case 'get_documents':
        $userId = findUserId($input['uid'] ?? '', $input['email'] ?? $_GET['email'] ?? '');
        if (!$userId) jsonOut(['success' => false, 'message' => 'User not found']);
        $st = db()->prepare('SELECT * FROM user_documents WHERE user_id=? ORDER BY uploaded_at DESC');
        $st->execute([$userId]);
        jsonOut(['success' => true, 'documents' => $st->fetchAll()]);

    // ─── ADMIN API ─────────────────────────────────────────────
    case 'admin_users':
        $pdo = db();
        $sql = 'SELECT u.id, u.email, u.name, u.profile_complete, u.created_at,
                       p.phone, p.gender, p.birth_date, p.interests, p.reason, p.goals, p.profile_image,
                       pr.current_streak, pr.best_streak, pr.total_activities
                FROM users u
                LEFT JOIN user_profiles p ON p.user_id = u.id
                LEFT JOIN user_progress pr ON pr.user_id = u.id
                ORDER BY u.id DESC';
        $users = $pdo->query($sql)->fetchAll();
        foreach ($users as &$u) {
            $uid = (int)$u['id'];
            $st = $pdo->prepare('SELECT content_type, COUNT(*) c FROM user_content WHERE user_id=? GROUP BY content_type');
            $st->execute([$uid]);
            $u['content_counts'] = $st->fetchAll();
            $st = $pdo->prepare('SELECT COUNT(*) c FROM chat_sessions WHERE user_id=?');
            $st->execute([$uid]);
            $u['chat_count'] = (int)$st->fetchColumn();
            $st = $pdo->prepare('SELECT COUNT(*) c FROM user_documents WHERE user_id=?');
            $st->execute([$uid]);
            $u['document_count'] = (int)$st->fetchColumn();
            $u['profile_image_url'] = imageUrl($u['profile_image'] ?? '');
        }
        jsonOut(['success' => true, 'users' => $users]);

    case 'admin_user_detail':
        $userId = (int)($input['user_id'] ?? $_GET['user_id'] ?? 0);
        if (!$userId) jsonOut(['success' => false, 'message' => 'user_id required']);
        jsonOut(array_merge(['success' => true], getAdminUserDetail($userId)));

    default:
        jsonOut(['success' => false, 'message' => 'Invalid action']);
    }
} catch (Throwable $e) {
    jsonOut(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}

