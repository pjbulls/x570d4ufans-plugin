<?php
header('Content-Type: application/json');

if (!function_exists('x570d4ufans_is_running')) {
  function x570d4ufans_is_running() {
    $pidFile = '/var/run/x570d4ufans.pid';
    if (!file_exists($pidFile)) return false;
    $pid = (int)trim(@file_get_contents($pidFile));
    if ($pid <= 0) return false;
    if (function_exists('posix_kill')) {
      return @posix_kill($pid, 0);
    }
    exec('kill -0 ' . $pid . ' 2>/dev/null', $out, $ret);
    return $ret === 0;
  }
}

$stateFile = '/var/local/x570d4ufans/state.json';
$data = null;
if (file_exists($stateFile)) {
  $raw = @file_get_contents($stateFile);
  $data = @json_decode($raw, true);
}
if (!is_array($data)) {
  $data = [];
}

$data['running'] = x570d4ufans_is_running();

echo json_encode($data);
?>