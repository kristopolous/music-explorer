<?php
$url = urldecode($_GET['u']);
$header = false;
$header_size = -1;

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL,$url);

curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_HEADER, 1);

curl_setopt($ch, CURLOPT_WRITEFUNCTION, function ($curl, $data) {
  global $header, $ch, $header_size;
  if(!$header) {
    $header_size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    if ($data === "\r\n") {
      $header = true;
    } else {
      if($header_size > 0) {
        header($data);
      }
      return strlen($data);
    }
  }
  echo $data;
  ob_flush();
  flush();
  return strlen($data);
});

curl_exec($ch);

