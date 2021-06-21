<?php
$file = $_GET['path'];
if(file_exists("$path")) {
  echo $path;
  exit;
}

$content =file_get_contents($_GET['u']);
preg_match('/(share.*data-url=")(https:[^"]*track[^"]*)/', $content, $matches);
$url = $matches[count($matches)-1];
echo shell_exec("youtube-dl -g $url");
