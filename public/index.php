<?php
declare(strict_types=1);

/*
 * PHP runtime check / fallback landing page.
 * The current systemd service serves public/index.html from Node.js.
 * This file confirms PHP CLI/FPM support; it is not a Laravel application.
 */
header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
?>
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MC Panel PHP Runtime</title></head>
<body style="font:16px system-ui;background:#0b0e15;color:#edf0fa;padding:3rem">
  <h1>MC Panel · PHP runtime check</h1>
  <p>PHP is installed as a runtime prerequisite. The main MC Panel UI is served by the Node.js service.</p>
  <p>PHP version: <strong><?= htmlspecialchars(PHP_VERSION, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?></strong></p>
</body>
</html>
