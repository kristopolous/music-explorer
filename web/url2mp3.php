<?php
$qual=intval($_GET['q']);

if (isset($_GET['path'])) {
  $path = $_GET['path'];
  if($qual < 1) {
    $smaller = str_replace(".mp3", '.opus', $path);
    if(file_exists("$smaller")) {
      echo $smaller;
      exit;
    }
  }
  if($qual < 2) {
    $smaller = str_replace(".mp3", '.m5a', $path);
    if(file_exists("$smaller")) {
      echo $smaller;
      exit;
    }
  }
  if(file_exists("$path")) {
    echo $path;
    exit;
  }
}

require "/usr/share/php/Predis/Autoloader.php";
Predis\Autoloader::register();
$client = new Predis\Client();
$src = $_GET['u'];
$key = "pl:$src";
$content = file_get_contents($src);
$mp3 = trim($client->get($key));
if(!$mp3) {
  preg_match('/(share.*data-url=")(https:[^"]*track[^"]*)/', $content, $matches);
  if(!$matches) {
    error_log(json_encode([$_GET['u'], $content] ));
  }
  $url = $matches[count($matches)-1];
  $mp3 = trim(shell_exec("yt-dlp -g $url"));
  $client->set($key, $mp3);
  $client->expire($key, 60 * 60 * 12);
}
$mp3 = str_replace('?', '%3f', $mp3);
$mp3 = str_replace('&', '%26', $mp3);
echo "/pl/fw.php?u=".$mp3;

