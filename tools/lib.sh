#!/bin/bash

[[ -z "$DIR" ]] && DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PLAYLIST=playlist.m3u

function hr {
  echo
  local len=$(tput cols)
  printf '\xe2\x80\x95%.0s' $( seq 1 $len )
  echo
}

function headline {
  case $1 in
    3)
      echo -e "\n\t$2"
      ;;
    2)
      echo -e "\n\t\033[1m$2\033[0m" 
      ;;
    1)
      up=$( echo "$2" | tr '[:lower:]' '[:upper:]' )
      echo -e "\n\t\033[1m$up\033[0m" 
      ;;
  esac
}

function status {
  [[ -n "$2" ]] && echo
  echo -e "\t\t$1"
}

_get_urls() {
  youtube-dl --get-duration --get-filename -gf mp3-128 -- "$1" | awk -f $DIR/ytdl2m3u.awk > "$2"
}

get_urls() {
  _get_urls $1 "$2/$PLAYLIST"
  echo $? > "$2"/exit-code
}

resolve() {
  if [[ -e "$1/domain" ]]; then
    echo $(< "$1/domain" )
  else
    label=$( dirname "$1" )
    [[ -e $label/domain ]] && domain=$(< $label/domain ) || domain=${label}.bandcamp.com
    release=$( basename "$1" )
    echo "https://$domain/album/$release"
  fi
}

get_playlist() {
  local dbg=/tmp/playlist-interim-$(date +%s)
  local failed=

  {
    youtube-dl -eif mp3-128 -- "$1" |\
      sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' > $dbg
  } >& /dev/null

  /bin/bash $dbg | grep mp3 > $PLAYLIST

  local tomatch=$(< $dbg | wc -l)
  local matched=$(< $PLAYLIST | wc -l)

  if [[ $tomatch != $matched ]]; then
    status "Hold on! - $matched != $tomatch" nl
    failed=1
  fi

  if [[ ! -s $PLAYLIST ]]; then 
    status "Unable to create $PLAYLIST, trying fallback" nl
    ls -1 "*.mp3" > $PLAYLIST >& /dev/null
    failed=1
  fi

  if [[ -n "$failed" ]]; then 
    status "Look in $dbg\n"
  else
    rm "$dbg"
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
