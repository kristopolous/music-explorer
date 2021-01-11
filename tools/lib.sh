#!/bin/bash

[[ -z "$DIR" ]] && DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PLAYLIST=playlist.m3u

_get_urls() {
  youtube-dl --get-duration --get-filename -gf mp3-128 -- "$1" | awk -f $DIR/ytdl2m3u.awk > "$2"
}
get_urls() {
  _get_urls $1 "$2/$PLAYLIST"
  echo $? > "$2"/exit-code
}

get_playlist() {
  local dbg=/tmp/playlist-interim-$(date +%s)
  local failed=

  youtube-dl -eif mp3-128 -- "$1" |\
    sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' > $dbg 

  /bin/bash $dbg | grep mp3 > $PLAYLIST

  local tomatch=$(< $dbg | wc -l)
  local matched=$(< $PLAYLIST | wc -l)

  if [[ $tomatch != $matched ]]; then
    echo -e "\n\t\tHold on! - $matched != $tomatch"
    failed=1
  fi

  if [[ ! -s $PLAYLIST ]]; then 
    echo -e "\n\t\tUnable to create $PLAYLIST, trying fallback"
    ls -1 "*.mp3" > $PLAYLIST >& /dev/null
    failed=1
  fi

  [[ -n "$failed" ]] && echo -e "\t\tLook in $dbg\n"
}

get_mp3s() {
  (
    cd "$2"
    youtube-dl -f mp3-128 -- "$1"
    echo $? > exit-code
    get_playlist "$1"
  )
}
