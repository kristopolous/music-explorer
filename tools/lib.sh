#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NONET=${NONET:=}
PLAYLIST=playlist.m3u
PAGE=page.html
STOPFILE=/tmp/mpvstop
FORMAT=mp3-128
SLEEP_MIN=1
SLEEP_MAX=4
SLEEP_OPTS="--max-sleep-interval $SLEEP_MAX --min-sleep-interval $SLEEP_MIN"

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

function info {
  echo -e "\t$1"
}
function status {
  [[ -n "$2" ]] && echo
  echo -e "\t\t$1"
}

check_url() {
  real_url=$(curl -Ls -o /dev/null -w %{url_effective} "$1")
  if [[ "$real_url" != "$1" ]]; then
    echo $real_url > "$2"/domain
    echo $real_url
  fi
}

_get_urls() {
  youtube-dl $SLEEP_OPTS \
    --get-duration --get-filename -gf $FORMAT -- "$1" \
    | awk -f $DIR/ytdl2m3u.awk > "$2"
}

_stub() {
  echo "$1" | tr '/' ':'
}

unlistened() {
  local filter=${1:-.}
  [[ $filter == '.' ]] && cmd=cat || cmd="grep -hE $filter" 
  if [[ -n "$NOSCORE" ]]; then
    $cmd .listen_all | cut -d ' ' -f 1 | shuf
  else
    $cmd .listen_all .listen_done | cut -d ' ' -f 1 | sort | uniq -u | shuf
  fi
}

recent() {
  echo */* | tr ' ' '\n' > .listen_all
  first=$(grep -m 1 "20[2-4][0-9]" .listen_done)
  first_date=${first##* }

  grep "20[2-4][0-9]" .listen_done | awk ' { print $NF } ' | sort | uniq -c
  ttl=$(wc -l .listen_all | awk ' { print $1 }').0
  done=$(wc -l .listen_done | awk ' { print $1 }').0
  wc -l .listen*
  echo $( perl -e "print 100 * $done / $ttl" )%
  du -sh
}

get_urls() {
  _get_urls $1 "$2/$PLAYLIST"
  local ec=$?
  if [[ $ec -ne 0 ]]; then
    local new_url=$(check_url "$2" "$2")
    if [[ -n "$new_url" ]]; then
      _get_urls "$new_url" "$2"
    fi
  else
    echo $? > "$2"/exit-code
  fi
}

album_purge() {
  local info="$1"
  local path="$2"
  
  [[ -e /tmp/"$path" ]] || mkdir -p /tmp/"$path"
  mv "$path"/* /tmp/"$path"
  echo "$1" > "$path"/no
}

purge() {
  album_purge "CLI" "$1"
}

resolve() {
  if [[ -e "$1/domain" ]]; then
    echo $(cat "$1/domain" )
  else
    label=$( dirname "$1" )
    [[ -e "$label/domain" ]] && domain=$(cat $label/domain ) || domain=${label/.\//}.bandcamp.com
    release=$( basename "$1" )
    echo "https://$domain/album/$release"
  fi
}

pl_check() {
  pl="$1/$PLAYLIST"

  [[ -e "$pl" && ! -s "$pl" ]] \
    && cat "$pl" \
    && status "Woops, empty playlist" \
    && rm "$pl"
}

pl_fallback() {
  ( 
    shopt -u nullglob
    cd "$1"
    ls -1 -- *.mp3 > $PLAYLIST 2> /dev/null
    shopt -s nullglob
  )
}

# Passes in a full path and
#
#   * checks for the page existence
#   * if not exist, then resolve it
#   * create file
#
get_page() {
  if [[ -s "$1/$PAGE" ]]; then
    curl -Ls $(resolve "$1") > "/tmp/$PAGE"
    if [[ $( stat -c %s "$1/$PAGE" ) -lt $( stat -c %s "/tmp/$PAGE" ) ]]; then
      mv "/tmp/$PAGE" "$1/$PAGE"
    fi
  else 
    echo $1
    curl -Ls $(resolve "$1") > "$1/$PAGE"
  fi
}

open_page() {
  [[ -z "$DISPLAY" ]] && export DISPLAY=:0
  if [[ $1 =~ http ]]; then
    xdg-open "$1"
  else
    [[ $# == '1' ]] && param="$1" || param="$2"
    local basedir=$(dirname "$param")
    local url=$(resolve "$basedir")
    xdg-open "$url"
  fi
}

get_playlist() {
  local dbg=/tmp/playlist-interim:$(_stub "$2"):$(date +%s)
  local failed=
  local tomatch=
  local matched=
  local path="$2"

  touch "$path/$PLAYLIST"

  if [[ -z "$NONET" ]]; then
    {
      echo "cd '$2'" > $dbg

      #$SLEEP_OPTS \
      youtube-dl \
        -eif $FORMAT -- "$1" |\
        sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' >> $dbg
    } 2> /dev/null
  
    /bin/bash $dbg | grep mp3 | sed -E 's/^/.\//g' > "$path/$PLAYLIST"
  fi

  # We want to support the nonet mode without
  # making things look broken
  
  # filter out the cd command
  [[ -e "$dbg" ]] && tomatch=$(grep -Ev "^cd " $dbg | wc -l)
  [[ -e "$path/$PLAYLIST" ]] && matched=$(cat "$path/$PLAYLIST" | wc -l)

  if [[ $tomatch != $matched ]]; then
    status "Hold on! - $tomatch != $matched" nl
    failed=1
  fi

  if [[ ! -s "$path/$PLAYLIST" ]]; then 
    status "Unable to create $PLAYLIST, trying fallback" nl
    pl_fallback "$path"
    failed=1
  fi

  pl_check "$path"

  if [[ -n "$failed" ]]; then 
    status "Look in $dbg\n"
  else
    _rm "$dbg"
  fi
}

_rm () {
  [[ -e "$1" ]] && rm "$1"
}

_tabs () {
  tabs 2,+4,+2,+10
}

_info () {
  local path="$1"
  local url=$(resolve "$path")
  local reldate="$(grep -m 1 -Po '((?<=release[sd] )[A-Z][a-z]+ [0-9]{1,2}, 20[0-9]{2})' "$path/$PAGE" )"
  _tabs

  headline 2  $url
  info        $path
  echo

  info "Released\t$(date --date="$reldate" -I)"
  info "Downloaded\t$(stat -c %w "$path/$PAGE" | cut -d ' ' -f 1 )"

  headline 2 Tracks
  grep -Po '((?<=track-title">).*?(?=<))' "$path/$PAGE" | awk ' { print "\t"FNR". "$0 } ' 

  headline 2 "Files"
  ( cd "$path"; ls -l *mp3 ) | sed 's/^/\t/' 
  echo
}


_ytdl () {
  if [[ -z "$NONET" ]]; then
    local url="$1"
    local path="$2"

    youtube-dl $SLEEP_OPTS \
      -o "$path/%(title)s-%(id)s.%(ext)s" \
      -f $FORMAT -- "$url"
    
    local ec=$?
    if [[ $ec -ne 0 ]]; then

      status "Checking $url"
      local new_url=$(check_url "$url" "$path")

      # This *shouldn't* lead to endless recursion, hopefully.
      if [[ -n "$new_url" ]]; then
        status "Trying again"
        _ytdl "$new_url" "$2"
      else
        status "Found nothing"
      fi
    else
      echo $ec > "$path"/exit-code
    fi
  fi

  check_for_stop
}

manual_pull() {
  local path="$2"
  local base=$( echo $1 | awk -F[/:] '{print $4}' )
  local track=

  echo " ▾▾ Manual Pull "

  for track in $(curl -s "$1" | grep -Po '((?!a href=\")/track\/[^\&"]*)' | sed -E s'/[?#].*//' | sort | uniq); do
    _ytdl "https://$base/$track" "$path"
  done

  pl_fallback "$path"
  pl_check "$path"
}

get_mp3s() {
  local url="$1"
  local path="$2"

  _ytdl "$url" "$path" 
  get_playlist "$url" "$path"
}
