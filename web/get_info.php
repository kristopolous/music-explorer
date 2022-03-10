<?php
$where = $_GET['p'];
$search = isset($_GET['q']) ? $_GET['q'] : false;
$dir = dirname($where);

$domain = file_get_contents("$dir/domain");

if(!file_exists("$dir/playlist.m3u")) {
  echo "http://9ol.es/$where";
} else {
  $playlist = file("$dir/playlist.m3u", FILE_IGNORE_NEW_LINES);
  if($search) {
    $playlist = preg_grep($search, $playlist);
  }
  $file = basename($where);

  for($ix = 0; $ix < count($playlist); $ix++) {
    if($playlist[$ix] == $file) {
      $offset = $ix + 1;
      break;
    }
  }
  echo shell_exec("yt-dlp -g --playlist-items $offset $domain");
}
