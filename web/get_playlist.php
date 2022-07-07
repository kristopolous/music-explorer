<?php
$off = 0;
$search = isset($_GET['q']) ? $_GET['q'] : false;
$parts = file('playlist.txt', FILE_IGNORE_NEW_LINES);
$ttl = 0;
$mt = function($m) { return $m; };

if($search === '.rand') {
  $mt_off = 100000 * floor(time() / (60 * 60 * 24));
  $mt = function($m) use ($ttl, $mt_off){ 
    global $ttl;
    mt_srand($m + $mt_off);
    return mt_rand(0, $ttl);
  };

} else if($search) {
  $parts = array_values(preg_grep("/$search/i", $parts));
}
if(count($parts) === 0) {
  $ret = [
    'ttl' => $ttl,
    'q' => $search,
    'res' => [],
    'off' => $off
  ];
} else {
  if(isset($_GET['off'])) {
    $off = $_GET['off'] % count($parts);
  }
  $ttl = count($parts);
  $start = 0;
  $ret = [
    'ttl' => $ttl,
    'q' => $search,
    'res' => [],
    'off' => $off
  ];
  for($ix = $off; $start < 10; $start++) {
    $ix_off = $mt($ix);
    $ret['res'][] = $parts[$ix_off];
    $ix = ($ix + 1) % $ttl;
  }
}


echo json_encode($ret);
