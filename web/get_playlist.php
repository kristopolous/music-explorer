<?php
$off = 0;
$search = isset($_GET['q']) ? $_GET['q'] : false;
$parts = file('playlist.txt', FILE_IGNORE_NEW_LINES);
$ttl = 0;
$skip = $_GET['skip'] ?? false;
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
$ttl = count($parts);

if($ttl === 0) {
  $ret = [
    'ttl' => $ttl,
    'q' => $search,
    'res' => [],
    'off' => $off
  ];
} else {
  if(isset($_GET['off'])) {
    $off = $_GET['off'] % $ttl;
  }
  if($skip) {
    if(!$off) {
      $off = 0;
    }
    $ix = $off;
    $dir = ($skip[0] != '-') * 2 - 1;

    $what = substr($skip, 1);
    $base = explode('/',$parts[$off]);
    $base_len = count($base);
    $release = $base[$base_len-2];
    $label = $base[$base_len-3];
    $start = $off;

    do {
      $ix = ($ix + $dir) % $ttl;
      $comp = explode('/',$parts[$ix]);
      $comp_len = count($comp);

      if(  ($what == 'release' && $comp[$comp_len-2] !== $release)  
        || ($what == 'label' && $comp[$comp_len-3] !== $label) 
        ) { 
        break;
      }
    } while ($ix != $off);

    $off = $ix;
  }

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
