<?php
$where = $_GET['p'];
$dir = dirname($where);

$domain = file_get_contents("$dir/domain");

if(!file_exists("$dir/playlist.m3u")) {
  echo "http://9ol.es/$where";
} else {
  $playlist = file("$dir/playlist.m3u", FILE_IGNORE_NEW_LINES);
  $file = basename($where);

  for($ix = 0; $ix < count($playlist); $ix++) {
    if($playlist[$ix] == $file) {
      $offset = $ix + 1;
      break;
    }
  }
  echo shell_exec("youtube-dl -g --playlist-items $offset $domain");
}
