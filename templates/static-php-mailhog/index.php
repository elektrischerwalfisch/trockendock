<?php
declare(strict_types=1);

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>Static PHP + Mailhog — Trockendock</title>
</head>
<body>
  <h1>Static PHP + Mailhog</h1>
  <p>PHP <?php echo htmlspecialchars(PHP_VERSION, ENT_QUOTES, 'UTF-8'); ?> is running.</p>
  <p>Mailhog UI: configure <code>MAILHOG_UI_PORT</code> in <code>.env</code>.</p>
</body>
</html>
