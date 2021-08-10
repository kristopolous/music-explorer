<?php
require "/usr/share/php/Predis/Autoloader.php";
Predis\Autoloader::register();

$client = new Predis\Client();
if (isset($_GET['path'])) {
  $path = $_GET['path'];

  if(file_exists("$path")) {
    echo $path;
    exit;
  }
}

$src = $_GET['u'];
$key = "pl:$src";
$content = file_get_contents($src);
$mp3 = $client->get($key);
if(!$mp3) {
  preg_match('/(share.*data-url=")(https:[^"]*track[^"]*)/', $content, $matches);
  $url = $matches[count($matches)-1];
  $mp3 = shell_exec("youtube-dl -g $url");
  $client->set($key, $mp3);
  $client->expire($key, 60 * 60 * 12);
}
echo $mp3;
