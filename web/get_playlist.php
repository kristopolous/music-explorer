<?php
$sql = new PDO('sqlite:playlist.db', false, false, [PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);

function get($qstr, $params = [], $type = false) {
  global $sql;

  foreach( $params as $k => $v ){
    if(empty($v)) {
      unset($params[$k]);
    }
  }

  $where_list = array_map(fn($v) => "$v = :$v", array_keys($params));
  if(isset($_GET['q'])) {
    $where_list[] = "path like :q";
    $params['q'] = "%${_GET['q']}%";
  }
  if(!empty($where_list)) { 
    $qstr .= " where " . implode (' and ', $where_list);
  }

  $prep = $sql->prepare("$qstr");
  $prep->execute($params);
  return $prep->fetchAll($type);
}

$_releaseMap = [];
function get_tracks($label = '', $release = '') {
  global $_releaseMap;
  if(!isset($_releaseMap["$label:$release"])) {
    $res = get("select track, path, label, release from tracks", ['label' => $label, 'release' => $release]);
    for($ix = 0; $ix < count($res); $ix++) {
      $res[$ix]['id'] = $ix;
    }
    $_releaseMap["$label:$release"] = $res;
  }
  return $_releaseMap["$label:$release"];
}

function get_releases($label) {
  global $_releaseMap;
  if(!isset($_releaseMap[$label])) {
    $releaseList = get("select distinct release from tracks", ['label' => $label], PDO::FETCH_COLUMN);
    mt_srand(floor(time() / (60 * 60 * 6)));
    shuffle($releaseList);
    $_releaseMap[$label] = $releaseList;
  }
  return $_releaseMap[$label];
}

$_labelList = false;
function get_labels() {
  global $_labelList;
  if(!$_labelList) {
    $labelList = get("select distinct label from tracks", [], PDO::FETCH_COLUMN);
    mt_srand(floor(time() / (60 * 60 * 6)));
    shuffle($labelList);
    $_labelList = $labelList;
  }
  return $_labelList;
}

function navigate($label, $release, $action, $final = false) {
  $label_ix = 0;
  $release_ix = 0;
  $track_ix = 0;
  $releaseList = [];

  $labelList = get_labels();

  if($action == "label") {
    return $labelList;
  }

  $dir = ($action[0] != '-') * 2 - 1;
  $what = substr($action, 1);

  if(!$label) {
    $label = $labelList[0];
  }

  if($what === 'label') {
    $isBack = $_GET['orig'] !== '-label' && $dir === -1;
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

  } else if ($what === 'release') {
    $releaseList = get_releases($label);
    $ttl = count($releaseList);
    if(!$ttl) {
      return compact('labelList', 'releaseList');
    }
    if($release) {
      $release_ix = array_search($release, $releaseList);
    }
    $release_ix = ($release_ix + $ttl + $dir) % $ttl;

    $release = $releaseList[$release_ix];
    $trackList = get_tracks($label, $release);

    if($_GET['orig'] === '-track') {
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
      $track_ix = $action;
    }
  }

  $payload = [
    'label' => $label,
    'release' => $release,
    'number' => $release_ix, 
    'count' => count($releaseList) 
  ];
  if($final) {
    $payload['path'] = $trackList[0]['path'];
    return $payload;
  }
  $payload[ 'trackList' ] = $trackList;
  $payload[ 'track_ix' ] = $track_ix;

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
