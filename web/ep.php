<?
$url=$_GET['u'];
$ck = md5($url);

if (!file_exists("tn/$ck.jpg")) {
  system ('curl -s ' . escapeshellarg($url) . ' | convert - -quality 40 -resize 1400\!x1400\! tn/' . $ck . '.jpg');
}
header("Content-type: image/jpeg");
echo file_get_contents("tn/$ck.jpg");
