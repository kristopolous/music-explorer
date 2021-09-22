#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NONET=${NONET:=}
NOPL=${NOPL:=}
DEBUG=${DEBUG:=}
PLAYLIST=playlist.m3u
PLAYLIST_DBG=
PAGE=page.html
STOPFILE=/tmp/mpvstop
FORMAT="-f mp3-128"
SLEEP_MIN=1
SLEEP_MAX=4
SLEEP_OPTS="--max-sleep-interval $SLEEP_MAX --min-sleep-interval $SLEEP_MIN"
DAY=86400

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

album_art() {
  for i in */*; do
    [[ ! -d $i ]] && continue

    if [[ ! -e $i/no && ! -e $i/album-art.jpg ]] ; then

      album=$(resolve $i)

      url=$(curl -Ls $album | grep -A 4 'tralbumArt' | grep popupImage | grep -Po 'https:.*[jp][pn]g')
      [[ -n "$url" ]] && curl -so $i/album-art.jpg $url
      echo "$url => $album"
    fi
  done
}

check_url() {
  real_url=$(curl -Ls -o /dev/null -w %{url_effective} "$1")
  if [[ "$real_url" != "$1" ]]; then
    echo $real_url > "$2"/domain
    echo $real_url
  fi
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
  # The great 2049 problem.
  # It will not be global environmental collapse.
  # NO! It will be this bash line.
  first=$(grep -m 1 "20[2-4][0-9]" .listen_done)
  first_date=${first##* }
  days=$(( ($(date +%s) - $(date --date=$first_date +%s)) / DAY ))

  grep "20[2-4][0-9]" .listen_done | awk ' { print $NF } ' | sort | uniq -c
  ttl=$(wc -l .listen_all | awk ' { print $1 }').0
  done=$(wc -l .listen_done | awk ' { print $1 }').0
  wc -l .listen*

  perl << END
    print 100 * $done / $ttl . "%\n";
    print "Listen:   " . $done / $days . "/day\n";
    print "Download: " . $ttl / $days . "/day\n";
END

  du -sh
}

_get_urls() {
  youtube-dl $SLEEP_OPTS \
    --get-duration --get-filename -g $FORMAT -- "$1" \
    | awk -f $DIR/ytdl2m3u.awk > "$2"
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

unpurge() {
  local path="$1"
  _rm "$path"/no 
  [[ -e /tmp/"$path" ]] && mv /tmp/"$path"/* "$path"
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
  PLAYLIST_DBG=/tmp/playlist-interim:$(_stub "$2"):$(date +%s)
  local failed=
  local tomatch=
  local matched=
  local path="$2"

  touch "$path/$PLAYLIST"

  if [[ -z "$NONET" ]]; then
    {
      echo "cd '$2'" > $PLAYLIST_DBG

      #$SLEEP_OPTS \
      youtube-dl \
        -ei $FORMAT -- "$1" |\
        sed -E 's/^([^-]*)\s?-?\s?(.*$)/compgen -G "\0"* || compgen -G "\2"*;/' >> $PLAYLIST_DBG
    } 2> /dev/null
  
    /bin/bash $PLAYLIST_DBG | grep mp3 | sed -E 's/^/.\//g' > "$path/$PLAYLIST"
  else
    info "Network is toggled off. Skipping playlist" 
  fi

  # We want to support the nonet mode without
  # making things look broken
  
  # filter out the cd command
  [[ -e "$PLAYLIST_DBG" ]] && tomatch=$(grep -Ev "^cd " $PLAYLIST_DBG | wc -l)
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
    status "Look in $PLAYLIST_DBG\n"
    #else
    #  _rm "$PLAYLIST_DBG"
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

  {
    headline 2  $url
    info        $path
    echo

    info "Released\t$(date --date="$reldate" -I)"
    info "Downloaded\t$(stat -c %w "$path/$PAGE" | cut -d ' ' -f 1 )"

    headline 2 Tracks
    grep -Po '((?<=track-title">).*?(?=<))' "$path/$PAGE" | awk ' { print FNR". "$0 } ' 

    headline 2 "Files"
    ( cd "$path"; ls -l *mp3 )

    headline 2 "PLS"
    cat "$path/playlist.m3u"
  } | sed -E 's/^([^\t])/\t\1/'

  echo
}


_ytdl () {
  if [[ -z "$NONET" ]]; then
    local url="$1"
    local path="$2"

    youtube-dl $SLEEP_OPTS \
      -o "$path/%(title)s-%(id)s.%(ext)s" \
      $FORMAT -- "$url"
    
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
  else
    info "Network is toggled off. Skipping ytdl"
  fi

  check_for_stop
}

manual_pull() {
  local path="$2"
  local base=$( echo $1 | awk -F[/:] '{print $4}' )
  local track=

  echo " ▾▾ Manual Pull "

  for track in $(curl -s "$1" | grep -Po '((?!a href=\")/track\/[^\&"]*)' | sed -E s'/[?#].*//' | sort | uniq); do
    _ytdl "https://$base/${track##/}" "$path"
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

details() {
  for pid in $(pgrep -f "^mpv "); do
    current=$(lsof -F n -p $pid | grep -E mp3\$ | cut -c 2-)
    track=$(basename "$current")

    release_path=$(dirname "$current")
    release=$(basename "$release_path")

    label_path=$(dirname "$release_path")
    label=$(basename "$label_path")
         
    if [[ -e $release_path/domain ]]; then
      release_url=$(< $release_path/domain ) 
    elif [[ -e $label_path/domain ]]; then
      release_url=$(< $label_path/domain )/$release
    else
      release_url=https://${label}.bandcamp.com/album/$release
    fi

    echo $release_url
    echo
    echo $label // $release
    echo ${track/-[0-9]*.mp3/}
    id3v2 -R "$current" | grep -E '^\w{4}\:'  | grep -vE '(APIC|TPE2|COMM)'
    echo "----- ($pid) ------"
  done
}
