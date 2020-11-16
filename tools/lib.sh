#!/bin/bash

[[ -z "$DIR" ]] && DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_get_urls() {
  youtube-dl --get-duration --get-filename -gf mp3-128 -- "$1" | awk -f $DIR/ytdl2m3u.awk > "$2"
}
get_urls() {
  _get_urls $1 "$2/url-list.m3u"
  echo $? > "$2"/exit-code
}

get_mp3s() {
  {
    cd "$2"
    youtube-dl -f mp3-128 -- "$1"
    echo $? > exit-code
  }
}
