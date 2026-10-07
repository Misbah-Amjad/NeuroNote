<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$usersFile = __DIR__ . '/users_n.json';
$action = $_GET['action'] ?? '';

function getUsers($file) {
    if (!file_exists($file)) {
        file_put_contents($file, json_encode([]));
    }
    $content = file_get_contents($file);
    return json_decode($content, true) ?: [];
}

function saveUsers($file, $users) {
    file_put_contents($file, json_encode($users, JSON_PRETTY_PRINT));
}

$input = json_decode(file_get_contents('php://input'), true) ?: [];

switch ($action) {
    case 'ping':
        echo json_encode(['success' => true, 'message' => 'Server is online']);
        break;

    case 'signup':
        $email = trim($input['email'] ?? '');
        $password = trim($input['password'] ?? '');
        if (!$email || !$password) {
            echo json_encode(['success' => false, 'message' => 'Email and password are required']);
            exit();
        }
        $users = getUsers($usersFile);
        foreach ($users as $u) {
            if ($u['email'] === $email) {
                echo json_encode(['success' => false, 'message' => 'Email already exists']);
                exit();
            }
        }
        $maxId = 0;
        foreach ($users as $u) {
            if (isset($u['id']) && $u['id'] > $maxId) {
                $maxId = $u['id'];
            }
        }
        $users[] = [
            'id' => $maxId + 1,
            'name' => explode('@', $email)[0],
            'email' => $email,
            'password' => password_hash($password, PASSWORD_DEFAULT),
            'created_at' => date('Y-m-d H:i:s'),
        ];
        saveUsers($usersFile, $users);
        echo json_encode(['success' => true, 'message' => 'Account created successfully']);
        break;

    case 'login':
        $email = trim($input['email'] ?? '');
        $password = trim($input['password'] ?? '');
        $users = getUsers($usersFile);
        foreach ($users as $u) {
            if ($u['email'] === $email && password_verify($password, $u['password'])) {
                echo json_encode([
                    'success' => true,
                    'message' => 'Login successful',
                    'uid' => (string)($u['id'] ?? ''),
                    'name' => $u['name'] ?? explode('@', $email)[0],
                    'email' => $email,
                    'profileComplete' => $u['profile_complete'] ?? false,
                ]);
                exit();
            }
        }
        echo json_encode(['success' => false, 'message' => 'Invalid email or password']);
        break;

    case 'save_profile':
        $uid   = trim($input['uid'] ?? '');
        $email = trim($input['email'] ?? '');
        if (!$uid && !$email) {
            echo json_encode(['success' => false, 'message' => 'uid or email is required']);
            exit();
        }
        $users = getUsers($usersFile);
        $found = false;
        foreach ($users as &$u) {
            // Match by uid (preferred) or email
            $matchUid   = $uid   && isset($u['id']) && (string)$u['id'] === $uid;
            $matchEmail = $email && isset($u['email']) && $u['email'] === $email;
            if ($matchUid || $matchEmail) {
                $u['name'] = trim($input['userName'] ?? $u['name'] ?? '');
                $u['bio'] = trim($input['userBio'] ?? $u['bio'] ?? '');
                $u['phone'] = trim($input['userPhone'] ?? $u['phone'] ?? '');
                $u['gender'] = trim($input['gender'] ?? $u['gender'] ?? '');
                $u['birth_date'] = trim($input['birthDate'] ?? $u['birth_date'] ?? '');
                $u['interests'] = $input['interests'] ?? $u['interests'] ?? [];
                $u['reason'] = trim($input['reason'] ?? $u['reason'] ?? '');
                $u['profile_image_base64'] = $input['userImageBase64'] ?? $u['profile_image_base64'] ?? '';
                $u['profile_complete'] = isset($input['profileComplete']) ? ($input['profileComplete'] == true) : ($u['profile_complete'] ?? false);
                $found = true;
                break;
            }
        }
        unset($u);
        if ($found) {
            saveUsers($usersFile, $users);
            echo json_encode(['success' => true, 'message' => 'Profile saved successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'User not found']);
        }
        break;

    case 'get_profile':
        $uid   = trim($input['uid'] ?? $_GET['uid'] ?? '');
        $email = trim($input['email'] ?? $_GET['email'] ?? '');
        if (!$uid && !$email) {
            echo json_encode(['success' => false, 'message' => 'uid or email is required']);
            exit();
        }
        $users = getUsers($usersFile);
        foreach ($users as $u) {
            // Match by uid (preferred) or email
            $matchUid   = $uid   && isset($u['id']) && (string)$u['id'] === $uid;
            $matchEmail = $email && isset($u['email']) && $u['email'] === $email;
            if ($matchUid || $matchEmail) {
                echo json_encode([
                    'success' => true,
                    'profile' => [
                        'uid' => (string)($u['id'] ?? ''),
                        'userName' => $u['name'] ?? '',
                        'userBio' => $u['bio'] ?? '',
                        'userEmail' => $u['email'],
                        'userPhone' => $u['phone'] ?? '',
                        'gender' => $u['gender'] ?? '',
                        'birthDate' => $u['birth_date'] ?? '',
                        'interests' => $u['interests'] ?? [],
                        'reason' => $u['reason'] ?? '',
                        'userImageBase64' => $u['profile_image_base64'] ?? '',
                        'profileComplete' => $u['profile_complete'] ?? false,
                    ]
                ]);
                exit();
            }
        }
        echo json_encode(['success' => false, 'message' => 'User not found']);
        break;

    case 'forgot_password':
        $email = trim($input['email'] ?? '');
        $users = getUsers($usersFile);
        $found = false;
        foreach ($users as $u) {
            if ($u['email'] === $email) {
                $found = true;
                break;
            }
        }
        if ($found) {
            echo json_encode(['success' => true, 'message' => 'Email verified']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Email not found']);
        }
        break;

    case 'reset_password':
        $email = trim($input['email'] ?? '');
        $newPassword = trim($input['new_password'] ?? '');
        if (!$email || !$newPassword) {
            echo json_encode(['success' => false, 'message' => 'Email and new password are required']);
            exit();
        }
        if (strlen($newPassword) < 6) {
            echo json_encode(['success' => false, 'message' => 'Password must be at least 6 characters']);
            exit();
        }
        $users = getUsers($usersFile);
        $updated = false;
        foreach ($users as &$u) {
            if ($u['email'] === $email) {
                $u['password'] = password_hash($newPassword, PASSWORD_DEFAULT);
                $updated = true;
                break;
            }
        }
        unset($u);
        if ($updated) {
            saveUsers($usersFile, $users);
            echo json_encode(['success' => true, 'message' => 'Password changed successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Email not found']);
        }
        break;

    case 'change_password':
        $email = trim($input['email'] ?? '');
        $currentPassword = trim($input['current_password'] ?? '');
        $newPassword = trim($input['new_password'] ?? '');
        if (!$email || !$currentPassword || !$newPassword) {
            echo json_encode(['success' => false, 'message' => 'All fields are required']);
            exit();
        }
        if (strlen($newPassword) < 6) {
            echo json_encode(['success' => false, 'message' => 'New password must be at least 6 characters']);
            exit();
        }
        $users = getUsers($usersFile);
        $updated = false;
        foreach ($users as &$u) {
            if ($u['email'] === $email) {
                if (!password_verify($currentPassword, $u['password'])) {
                    echo json_encode(['success' => false, 'message' => 'Current password is incorrect']);
                    exit();
                }
                $u['password'] = password_hash($newPassword, PASSWORD_DEFAULT);
                $updated = true;
                break;
            }
        }
        unset($u);
        if ($updated) {
            saveUsers($usersFile, $users);
            echo json_encode(['success' => true, 'message' => 'Password changed successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'User not found']);
        }
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        break;
}
