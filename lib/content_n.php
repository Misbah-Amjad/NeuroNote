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

$contentFile = __DIR__ . '/user_content_n.json';
$action = $_GET['action'] ?? '';

// ─── Helpers ────────────────────────────────────────────────────────

function getContentStore($file) {
    if (!file_exists($file)) {
        file_put_contents($file, json_encode([]));
    }
    $content = file_get_contents($file);
    return json_decode($content, true) ?: [];
}

function saveContentStore($file, $data) {
    file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT));
}

$input = json_decode(file_get_contents('php://input'), true) ?: [];

switch ($action) {

    // ─── Save a generated content item ─────────────────────────────
    case 'save_content':
        $email = trim($input['email'] ?? '');
        if (!$email) {
            echo json_encode(['success' => false, 'message' => 'Email is required']);
            exit();
        }

        $type    = trim($input['type'] ?? '');
        $id      = trim($input['id'] ?? '');
        $title   = trim($input['title'] ?? '');
        $content = $input['content'] ?? '';
        $itemAction = trim($input['action'] ?? '');
        $timestamp  = trim($input['timestamp'] ?? date('Y-m-d\TH:i:s'));
        $date       = trim($input['date'] ?? date('d/m/Y'));

        if (!$type || !$id) {
            echo json_encode(['success' => false, 'message' => 'type and id are required']);
            exit();
        }

        $store = getContentStore($contentFile);

        if (!isset($store[$email])) {
            $store[$email] = [
                'flashcards' => [],
                'quizzes'    => [],
                'summaries'  => [],
                'audio_notes'=> [],
                'progress'   => [],
            ];
        }

        $entry = [
            'id'        => $id,
            'title'     => $title,
            'content'   => $content,
            'action'    => $itemAction,
            'timestamp' => $timestamp,
            'date'      => $date,
        ];

        // Merge any extra fields passed (e.g. cards, questions, imageBase64)
        $skip = ['email', 'type', 'id', 'title', 'content', 'action', 'timestamp', 'date'];
        foreach ($input as $k => $v) {
            if (!in_array($k, $skip)) {
                $entry[$k] = $v;
            }
        }

        $listKey = $type; // 'flashcards', 'quizzes', 'summaries', 'audio_notes'
        if (!isset($store[$email][$listKey])) {
            $store[$email][$listKey] = [];
        }

        // Prevent duplicates by id
        $store[$email][$listKey] = array_values(
            array_filter($store[$email][$listKey], fn($x) => ($x['id'] ?? '') !== $id)
        );
        // Prepend so newest is first
        array_unshift($store[$email][$listKey], $entry);

        saveContentStore($contentFile, $store);
        echo json_encode(['success' => true, 'message' => 'Content saved']);
        break;

    // ─── Get all content for a user ─────────────────────────────────
    case 'get_content':
        $email = trim($input['email'] ?? $_GET['email'] ?? '');
        if (!$email) {
            echo json_encode(['success' => false, 'message' => 'Email is required']);
            exit();
        }

        $store = getContentStore($contentFile);
        $userData = $store[$email] ?? [
            'flashcards' => [],
            'quizzes'    => [],
            'summaries'  => [],
            'audio_notes'=> [],
        ];

        $typeFilter = trim($input['type'] ?? $_GET['type'] ?? '');
        if ($typeFilter && isset($userData[$typeFilter])) {
            echo json_encode([
                'success' => true,
                'data'    => $userData[$typeFilter],
            ]);
        } else {
            echo json_encode([
                'success' => true,
                'data'    => [
                    'flashcards'  => $userData['flashcards']  ?? [],
                    'quizzes'     => $userData['quizzes']     ?? [],
                    'summaries'   => $userData['summaries']   ?? [],
                    'audio_notes' => $userData['audio_notes'] ?? [],
                ],
            ]);
        }
        break;

    // ─── Delete a content item ───────────────────────────────────────
    case 'delete_content':
        $email = trim($input['email'] ?? '');
        $type  = trim($input['type'] ?? '');
        $id    = trim($input['id'] ?? '');

        if (!$email || !$type || !$id) {
            echo json_encode(['success' => false, 'message' => 'email, type, and id are required']);
            exit();
        }

        $store = getContentStore($contentFile);
        if (isset($store[$email][$type])) {
            $store[$email][$type] = array_values(
                array_filter($store[$email][$type], fn($x) => ($x['id'] ?? '') !== $id)
            );
            saveContentStore($contentFile, $store);
        }

        echo json_encode(['success' => true, 'message' => 'Content deleted']);
        break;

    // ─── Save / update progress (streak, weekly data) ───────────────
    case 'save_progress':
        $email = trim($input['email'] ?? '');
        if (!$email) {
            echo json_encode(['success' => false, 'message' => 'Email is required']);
            exit();
        }

        $store = getContentStore($contentFile);
        if (!isset($store[$email])) {
            $store[$email] = [];
        }

        $store[$email]['progress'] = [
            'current_streak'   => $input['current_streak']   ?? 0,
            'best_streak'      => $input['best_streak']       ?? 0,
            'last_active_date' => $input['last_active_date']  ?? '',
            'total_activities' => $input['total_activities']  ?? 0,
            'weekly_data'      => $input['weekly_data']       ?? [],
            'week_start'       => $input['week_start']        ?? '',
            'last_updated'     => date('Y-m-d\TH:i:s'),
        ];

        saveContentStore($contentFile, $store);
        echo json_encode(['success' => true, 'message' => 'Progress saved']);
        break;

    // ─── Get progress for a user ─────────────────────────────────────
    case 'get_progress':
        $email = trim($input['email'] ?? $_GET['email'] ?? '');
        if (!$email) {
            echo json_encode(['success' => false, 'message' => 'Email is required']);
            exit();
        }

        $store = getContentStore($contentFile);
        $progress = $store[$email]['progress'] ?? null;

        echo json_encode([
            'success'  => true,
            'progress' => $progress,
        ]);
        break;

    // ─── Get dashboard stats for a user ─────────────────────────────
    case 'get_stats':
        $email = trim($input['email'] ?? $_GET['email'] ?? '');
        if (!$email) {
            echo json_encode(['success' => false, 'message' => 'Email is required']);
            exit();
        }

        $store    = getContentStore($contentFile);
        $userData = $store[$email] ?? [];

        $flashcardCount = count($userData['flashcards']  ?? []);
        $quizCount      = count($userData['quizzes']     ?? []);
        $summaryCount   = count($userData['summaries']   ?? []);
        $audioCount     = count($userData['audio_notes'] ?? []);
        $totalItems     = $flashcardCount + $quizCount + $summaryCount + $audioCount;

        $progress = $userData['progress'] ?? null;

        echo json_encode([
            'success' => true,
            'stats'   => [
                'flashcard_count' => $flashcardCount,
                'quiz_count'      => $quizCount,
                'summary_count'   => $summaryCount,
                'audio_count'     => $audioCount,
                'total_items'     => $totalItems,
                'current_streak'  => $progress['current_streak']  ?? 0,
                'best_streak'     => $progress['best_streak']      ?? 0,
                'total_activities'=> $progress['total_activities'] ?? 0,
                'weekly_data'     => $progress['weekly_data']      ?? [],
                'week_start'      => $progress['week_start']       ?? '',
                'last_active_date'=> $progress['last_active_date'] ?? '',
            ],
        ]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        break;
}
