<?php
$off = 0;
$parts = file('playlist.txt', FILE_IGNORE_NEW_LINES);
if(isset($_GET['off'])) {
  $off = $_GET['off'] % count($parts);
}
$start = 0;
$ret = [];
for($ix = $off; $start < 10; $start++) {
  $ret[] = $parts[$ix];
  $ix = ($ix + 1) % count($parts);
}


echo json_encode($ret);
