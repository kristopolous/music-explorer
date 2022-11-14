<?
header("Content-Type: application/xml; charset=UTF-8");
echo "<?xml version='1.0' encoding='UTF-8'?>";
?>
<rss version="2.0"
    xmlns:dc="http://purl.org/dc/elements/1.1/" 
    xmlns:media="http://search.yahoo.com/mrss/" 
    xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" 
    xmlns:content="http://purl.org/rss/1.0/modules/content/"
    xmlns:atom="http://www.w3.org/2005/Atom" 
    xmlns:feedburner="http://rssnamespace.org/feedburner/ext/1.0" 
  >
  <channel>
    <itunes:summary>Music that isn't terrible</itunes:summary>
    <itunes:subtitle>mtint</itunes:subtitle>
    <itunes:category text="Music" />
    <title>Music That Isn't Terrible</title>
    <link>https://9ol.es/pl/rss</link>
    <copyright>probably</copyright>
    <description>See https://github.com/kristopolous/music-explorer and https://facebook.com/groups/mtint</description>
    <language>en</language>
    <itunes:image href="http://indycast.net/icon/mtint_1400.png?202211"/>
    <media:thumbnail url="http://indycast.net/icon/mtint_1400.png?202211"/>
    <atom:link href="https://9ol.es/pl" type="application/rss+xml" rel="self"/>
    <image>
      <url>http://indycast.net/icon/mtint_200.png?202211</url>
      <title>mtint</title>
      <link>https://9ol.es/pl</link>
    </image>
<?php

$shareRaw = file_get_contents("/raid/mp3/label/.share_list");
// pass 1 is simply looking at the record seperator
$recordList = array_reverse(preg_split("/\n\n/", trim($shareRaw)));


foreach($recordList as $record) {
  list($time,$path,$url,$image,$size,$dur) = array_map(function ($str) { 
    return trim(htmlspecialchars($str, ENT_XML1)); 
  }, preg_split('/\n/', $record));
  $title = preg_replace('/-\d+.mp3/', '', basename($path));
  $duration = sprintf("%d:%02d:%02d", floor($dur/3600), ($dur/60)%60, ($dur)%60);

  $date = gmdate("D, d M Y H:i:s O", intval($time));
  $audio = "https://9ol.es$path";

  $parts = explode('/', $path);
  $label = ucfirst(preg_replace('/\-/', ' ', $parts[count($parts)-2]));

  ?>
  <item>
      <title><?= $title ?> / <?= $label ?></title>
      <description><?= $url ?></description>
      <itunes:episodeType>full</itunes:episodeType>
      <itunes:explicit>false</itunes:explicit>
      <itunes:author>mtint</itunes:author>
      <itunes:duration><?= floor($dur) ?></itunes:duration>
      <itunes:subtitle></itunes:subtitle>
      <itunes:summary>mtint</itunes:summary>
      <itunes:image 
          href="https://9ol.es/pl/ep?u=<?=$image ?>"
      />
      <dc:creator>mtint</dc:creator>
      <feedburner:origEnclosureLink><?= $audio ?></feedburner:origEnclosureLink>
      <feedburner:origLink>https://9ol.es/pl</feedburner:origLink>
      <pubDate><?= $date ?></pubDate>
      <link><?= $audio ?></link>
      <copyright>probably</copyright>
      <guid isPermaLink="true"><?= md5($path) ?></guid>
      <media:thumbnail url="<?=$image ?>"/>
      <media:content url="<?= $audio ?>" fileSize="<?= $size ?>" type="audio/mpeg"/>
      <enclosure url="<?= $audio ?>" length="<?= $size ?>" type="audio/mpeg"/>
    </item>
  <?
}
?>
  </channel>
</rss>
