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
  [[ -e $PLAYLIST ]] || youtube-dl -eif mp3-128 -- "$1" |\
    sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' > $dbg 

  echo $dbg
  tomatch=$(cat $dbg | wc -l)

  /bin/bash $dbg | grep mp3 > $PLAYLIST

  matched=$(cat $PLAYLIST | wc -l)

  echo $tomatch " --- " $matched

  if [[ $tomatch != $matched ]]; then
    echo "Woah hold on"
    exit
  fi

  if [[ ! -s $PLAYLIST ]]; then 
    echo "unable to create $PLAYLIST, doing fallback"
    ls -1 "*.mp3" > $PLAYLIST 
  fi
}

get_mp3s() {
  (
    cd "$2"
    youtube-dl -f mp3-128 -- "$1"
    echo $? > exit-code
    echo "---exit code---"
    echo $PWD $(cat exit-code)
  )
}
