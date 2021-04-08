#!/bin/bash

[[ -z "$DIR" ]] && DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PLAYLIST=playlist.m3u
PAGE=page.html
STOPFILE=/tmp/mpvstop

function hr {
  echo
  local len=$(tput cols)
  printf '\xe2\x80\x95%.0s' $( seq 1 $len )
  echo
}

check_for_stop() {
  if [[ -e $STOPFILE ]]; then
    echo "Stopping because $STOPFILE exists"
    exit
  fi
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

pl_check() {
  [[ -e $PLAYLIST && ! -s $PLAYLIST ]] && cat $PLAYLIST && status "Woops, empty playlist" && rm $PLAYLIST
}

pl_fallback() {
  shopt -u nullglob
  ls -1 -- *.mp3 > $PLAYLIST 2> /dev/null
  shopt -s nullglob
}

# Passes in a full path and
#
#   * checks for the page existence
#   * if not exist, then resolve it
#   * create file
#
get_page() {
  [[ -s "$1/$PAGE" ]] || curl -s $(resolve "$1") > "$1/$PAGE"
}
open_page() {
  xdg-open "$(resolve $(dirname "$1"))"
}

get_playlist() {
  local dbg=/tmp/playlist-interim-$(date +%s)
  local failed=

  {
    youtube-dl -eif mp3-128 -- "$1" |\
      sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' > $dbg
  } 2> /dev/null

  /bin/bash $dbg | grep mp3 > $PLAYLIST

  local tomatch=$(< $dbg | wc -l)
  local matched=$(< $PLAYLIST | wc -l)

  if [[ $tomatch != $matched ]]; then
    status "Hold on! - $matched != $tomatch" nl
    failed=1
  fi

  if [[ ! -s $PLAYLIST ]]; then 
    status "Unable to create $PLAYLIST, trying fallback" nl
    pl_fallback
    failed=1
  fi

  pl_check

  if [[ -n "$failed" ]]; then 
    status "Look in $dbg\n"
  else
    rm "$dbg"
  fi
}

manual_pull() {
  (
    echo " ▾▾ Manual Pull "
    local base=$( echo $1 | awk -F[/:] '{print $4}' )
    cd "$2"

    for track in $(curl -s "$1" | grep -Po '((?!a href=\")/track\/[^\&"]*)' | sort | uniq); do
      youtube-dl -f mp3-128 -- "https://$base/$track"
      check_for_stop
    done

    pl_fallback
    pl_check
  )
}

get_mp3s() {
  (
    cd "$2"
    youtube-dl -f mp3-128 -- "$1"
    check_for_stop 
    echo $? > exit-code
    get_playlist "$1"
  )
}
