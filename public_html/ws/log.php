<?
$path = $cfg_dir."/logs/log.txt";
$logfile = fopen($path, "a+") or die($path);

function write_log($msg) {
  global $logfile;
  fwrite($logfile, $msg);
}

write_log(sprintf("=== %s ===\n", date("d.m.Y H:i:s")));
?>
