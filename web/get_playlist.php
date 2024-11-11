<?php
$_sql = new PDO('sqlite:playlist.db', false, false, [PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
$_chrono = $_GET['chrono'] ?? false;
$_releaseMap = [];
$_dir = $_GET['orig'] ?? false;

function get($qstr, $params = [], $type = false) {
  global $_sql;
  $extra = '';
  if(isset($params['_extra'])) {
    $extra = $params['_extra'];
    unset($params['_extra']);
  }

  foreach( $params as $k => $v ){
    if(empty($v)) {
      unset($params[$k]);
    }
  }

  $where_list = array_map(fn($v) => "$v = :$v", array_keys($params));
  if(!empty($_GET['q'])) {
    $where_list[] = "path like :q";
    $params['q'] = "%${_GET['q']}%";
  }
  if(!empty($where_list)) { 
    $qstr .= " where " . implode (' and ', $where_list);
  }

  $qstr .= " ${extra}";
  $qstr .= " order by created_at desc limit 1000";
  $prep = $_sql->prepare($qstr);
  //error_log($qstr . json_encode($params));
  $prep->execute($params);
  return $prep->fetchAll($type);
}

function get_tracks($label = '', $release = '') {
  global $_releaseMap;
  if(!isset($_releaseMap["$label:$release"])) {
    $res = get("select track, path, label, release from tracks", ['label' => $label, 'release' => $release]);
    for($ix = 0; $ix < count($res); $ix++) {
      $res[$ix]['id'] = empty($release) ? 0 : $ix;
    }
    $_releaseMap["$label:$release"] = $res;
  }
  return $_releaseMap["$label:$release"];
}

function search_releases($label = '') {
  $res = get("select path, label, release from tracks", [ 
    "_extra" => "group by label, release",
    'label' => $label
  ]);
  for($ix = 0; $ix < count($res); $ix++) {
    $res[$ix]['id'] = 0;
  }
  return $res;
}

function get_releases($label = '') {
  global $_releaseMap, $_chrono;
  if(!isset($_releaseMap[$label])) {
    $releaseList = get("select distinct release from tracks", ['label' => $label], PDO::FETCH_COLUMN);
    if(!$_chrono) {
      mt_srand(floor(time() / (60 * 60 * 6)));
      shuffle($releaseList);
    }
    $_releaseMap[$label] = $releaseList;
  }
  return $_releaseMap[$label];
}

$_labelList = false;
function get_labels() {
  global $_labelList, $_chrono;
  if(!$_labelList) {
    $labelList = get("select distinct label from tracks", [], PDO::FETCH_COLUMN);
    if(!$_chrono) {
      mt_srand(floor(time() / (60 * 60 * 6)));
      shuffle($labelList);
    }
    $_labelList = $labelList;
  }
  return $_labelList;
}

// This is always run - and it's run recursively
function navigate($label, $release, $action, $final = false) {
  global $_dir;
  //error_log(implode(" ---- ", [$label, $release, $action, $final]));
  $label_ix = 0;
  $track_ix = 0;
  $release_ix = 0;
  $releaseList = [];

  $labelList = get_labels();

  if($action == "label") {
    return $labelList;
  }

  // This is for the tab and the search.
  // This doesn't ever get a $_dir
  if(!$_dir && $action === "release") {
    $res = search_releases($label);
    if(empty($res)) {
      $res = search_releases('');
    }
    return $res;
  }

  $dir = ($action[0] != '-') * 2 - 1;
  $action_ = substr($action, 1);//"-+");

  if(!$label && empty($_GET['q']) ) {
    $label = $labelList[0];
  }

  if($action_ === 'label') {
    $isBack = $_dir !== '-label' && $dir === -1;
    $ttl = count($labelList);
    if(!$ttl) {
      return compact('labelList');
    }
    if($label) {
      $label_ix = array_search($label, $labelList);
    }
    $label_ix = ($label_ix + $ttl + $dir) % $ttl;

    $label = $labelList[$label_ix];
    $releaseList = get_releases($label);

    if($isBack) {
      $release_ix = count($releaseList) - 1;
    } 
    $release = $releaseList[$release_ix];
    $trackList = get_tracks($label, $release);

    if($isBack) {
      $track_ix = count($trackList) - 1;
    } 

  } else if ($action_ === 'release') {
    $releaseList = get_releases($label);
    $ttl = count($releaseList);
    // If there's no results then we have selected a label 
    // and have a search string with no results. Instead 
    // under this use-case we should probably just give
    // all the releases

    if($ttl === 0) {
      return compact('labelList', 'releaseList');
      // we need to redo everything! Auckkk
      // this will take our search string
      $releaseList = get_releases();
      $ttl = count($releaseList);
      if(!$ttl) {
        return compact('labelList', 'releaseList');
      }
      return $releaseList;
    }
    if($release) {
      $release_ix = array_search($release, $releaseList);
    }
    $release_ix = ($release_ix + $ttl + $dir) % $ttl;

    $release = $releaseList[$release_ix];
    $trackList = get_tracks($label, $release);

    if($_dir === '-track') {
      $track_ix = count($trackList) - 1;
    }
  } else {
    $releaseList = get_releases($label);
    if($action == "release") {
      return $releaseList;
    }

    if(!$release) {
      $release = $releaseList[0];
    } else {
      $release_ix = array_search($release, $releaseList);
    }
    $trackList = get_tracks($label, $release);
    if($action == "track") {
      if(empty($trackList) && $release) {
        $trackList = get_tracks($label);
      }
      if(empty($trackList) && $label) {
        $trackList = get_tracks();
      }
      return $trackList;
    }

    if(is_numeric($action)) {
      $track_ix = min($action, count($trackList) - 1);
    }
  }

  $payload = [
    'label' => $label,
    'release' => $release,
    'number' => $release_ix, 
    'count' => count($releaseList),
    'track_ix' => $track_ix,
    'trackList' => $trackList
  ];
  if($final) {
    if(isset($trackList[$track_ix])) {
      $payload = array_merge($payload, $trackList[$track_ix]);
    }
    return $payload;
  }

  return [
    'release' => $payload,
    '+label' => navigate($label, $release, "+label", true),
    '-release' => navigate($label, $release, "-release", true),
    '+release' => navigate($label, $release, "+release", true)
  ];
}

echo json_encode(navigate(
  $_GET['label'] ?? false,
  $_GET['release'] ?? false,
  $_GET['action'] ?? "+track"
));
