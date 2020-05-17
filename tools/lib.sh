#!/bin/bash
get_urls() {
   youtube-dl --get-duration --get-filename -gf mp3-128 -- "$1" | awk $DIR/ytdl2m3u.awk > "$2"/url-list.m3u
   echo $? > "$2"/exit-code
}
get_mp3s() {
  cd "$2"
  youtube-dl -f mp3-128 -- "$1"
  echo $? > "$2"/exit-code
}
