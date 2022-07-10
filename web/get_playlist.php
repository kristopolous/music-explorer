<?php
$sql = new PDO('sqlite:playlist.db', false, false, [PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);

function get($qstr, $params = [], $type = false) {
  global $sql;

  $where_list = array_map(fn($v) => "$v = :$v", array_keys($params));
  if(isset($_GET['q'])) {
    $where_list[] = "path like :q";
    $params['q'] = "%${_GET['q']}%";
  }
  if(!empty($where_list)) { 
    $qstr .= " where " . implode (' and ', $where_list);
  }

  //error_log(json_encode(["$qstr $where_str", $params]));
  $prep = $sql->prepare("$qstr");
  $prep->execute($params);
  return $prep->fetchAll($type);
}

$_releaseMap = [];
function get_tracks($label, $release) {
  global $_releaseMap;
  if(!isset($_releaseMap["$label:$release"])) {
    $res = get("select title,path from tracks", ['label' => $label, 'release' => $release]);
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
    mt_srand(floor(time() / (60 * 60 * 24)));
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
    mt_srand(floor(time() / (60 * 60 * 24)));
    shuffle($labelList);
    $_labelList = $labelList;
  }
  return $_labelList;
}

function navigate($label, $release, $direction, $final = false) {
  $dir = ($direction[0] != '-') * 2 - 1;
  $what = substr($direction, 1);

  $label_ix = 0;
  $release_ix = 0;
  $releaseList = [];

  $labelList = get_labels();

  if(!$label) {
    $label = $labelList[0];
  }

  if($what === 'label') {
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
    $release = $releaseList[0];
    $trackList = get_tracks($label, $release);

  } else if ($what === 'release') {
    $releaseList = get_releases($label);
    error_log(json_encode($releaseList));
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
  } else {
    $releaseList = get_releases($label);
    if(!$release) {
      $release = $releaseList[0];
    } else {
      $release_ix = array_search($release, $releaseList);
    }
    $trackList = get_tracks($label, $release);
  }

  $payload = [
    'label' => $label,
    'title' => $release,
    'number' => $release_ix, 
    'count' => count($releaseList) 
  ];
  if($final) {
    $payload['path'] = $trackList[0]['path'];
    return $payload;
  }
  $payload[ 'trackList' ] = $trackList;

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
  $_GET['skip'] ?? "+track"
));
