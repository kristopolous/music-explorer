<?php
$off = 0;
$search = isset($_GET['q']) ? $_GET['q'] : false;
$parts = file('playlist.txt', FILE_IGNORE_NEW_LINES);
if($search) {
  $parts = array_values(preg_grep("/$search/i", $parts));
}
if(isset($_GET['off'])) {
  $off = $_GET['off'] % count($parts);
}
$start = 0;
$ret = [
  'ttl' => count($parts),
  'q' => $search,
  'res' => [],
  'off' => $off
];
for($ix = $off; $start < 10; $start++) {
  $ret['res'][] = $parts[$ix];
  $ix = ($ix + 1) % count($parts);
}


echo json_encode($ret);
