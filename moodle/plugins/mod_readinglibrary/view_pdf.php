<?php
// Secure PDF streaming endpoint.
// Nginx blocks direct .pdf access; all reads go through this script.

require_once('../../config.php');

use mod_readinglibrary\borrow_manager;

require_login();

$token = required_param('token', PARAM_ALPHANUM);

$manager = new borrow_manager($DB);

try {
    $filepath = $manager->redeem_token($token);
} catch (\moodle_exception $e) {
    http_response_code(403);
    die('Access denied.');
}

$absolute = $CFG->dataroot . '/' . ltrim($filepath, '/');

if (!is_file($absolute) || !is_readable($absolute)) {
    http_response_code(404);
    die('File not found.');
}

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="document.pdf"');
header('Content-Length: ' . filesize($absolute));
header('Cache-Control: no-store, no-cache, must-revalidate');
header('X-Content-Type-Options: nosniff');

// Disable output buffering so large PDFs stream without memory pressure
while (ob_get_level()) {
    ob_end_clean();
}

readfile($absolute);
