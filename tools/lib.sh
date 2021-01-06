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
  dbg=/tmp/playlist-interim-$(date +%s)

  youtube-dl -eif mp3-128 -- "$1" |\
    sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' > $dbg 

  tomatch=$(cat $dbg | wc -l)

  /bin/bash $dbg | grep mp3 > $PLAYLIST

  matched=$(cat $PLAYLIST | wc -l)

  if [[ $tomatch != $matched ]]; then
    echo -e "\n    $matched - $tomatch"
    echo -e "    Hold on - there's a mismatch!"
    echo -e "    Look in - $dbg\n"
  fi

  if [[ ! -s $PLAYLIST ]]; then 
    echo $dbg
    echo -e "\n  Unable to create $PLAYLIST, trying fallback\n"
    ls -1 "*.mp3" > $PLAYLIST  >& /dev/null
  fi
}

get_mp3s() {
  (
    cd "$2"
    youtube-dl -f mp3-128 -- "$1"
    echo $? > exit-code
    get_playlist "$1"
  )
}
