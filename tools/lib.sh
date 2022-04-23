#!/bin/bash

tmp=/tmp/mpvonce
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUPDIR=$HOME/.mpvonce
UNDODIR=$tmp/undo
NONET=${NONET:=}
NOSCAN=${NOSCAN:=}
NOUNDO=${NOUNDO:=}
NOPL=${NOPL:=}
DEBUG=${DEBUG:=}
PLAYLIST=playlist.m3u
PLAYLIST_DBG=
YTDL=yt-dlp
PAGE=page.html
STOPFILE=$tmp/mpvstop
FORMAT="-f mp3-128"
SLEEP_MIN=1
SLEEP_MAX=4
SLEEP_OPTS="--max-sleep-interval $SLEEP_MAX --min-sleep-interval $SLEEP_MIN"
[[ -e $DIR/prefs.sh ]] && . $DIR/prefs.sh

# some simple things first.
_rm ()  { [[ -e "$1" ]] && rm "$1"; }
_mkdir(){ [[ -e "$1" ]] || mkdir -p "$1"; }
_tabs() { tabs 2,+4,+2,+10; }
_stub() { echo "$1" | tr '/' ':'; }
info()  { echo -e "\t$1"; }
debug() { [[ -n "$DEBUG" ]] && echo -e "\t$1"; }
purge() { album_purge "CLI" "$1"; }
getvar() { echo ${!1}; }

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

announce() {
  [[ -n "$announce" ]] && echo "$*" | aosd_cat -p 2  -n "Noto Sans Condensed ExtraBold 150" -R white -f 1000 -u 15000 -o 2000 -x -20 -y 20 -d 50 -r 190 -b 216 -S black -e 2 -B black -w 3600 -b 200&
}

function headline {
  [[ $1 == "3" ]] && echo -e "\n\t$2"
  [[ $1 == "2" ]] && echo -e "\n\t\033[1m$2\033[0m" 
  if [[ $1 == "1" ]]; then
    up=$( echo "$2" | tr '[:lower:]' '[:upper:]' )
    echo -e "\n\t\033[1m$up\033[0m" 
  fi
}

status() {
  [[ -n "$2" ]] && echo
  echo -e "\t\t$1"
}

backup() {
  _mkdir $BACKUPDIR
  backupname=$(date +%Y%m%d).tbz
  tar cjf $BACKUPDIR/$backupname .dl_history .listen_all .listen_done
  debug "Backing up to $BACKUPDIR/$backupname"
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


unlistened() {
  local filter=${1:-.}
  [[ $filter == '.' ]] && cmd=cat || cmd="grep -hE $filter" 
  if [[ -n "$NOSCORE" ]]; then
    $cmd $start_dir/.listen_all | cut -d ' ' -f 1 | shuf
  else
    $cmd $start_dir/.listen_all $start_dir/.listen_done | cut -d ' ' -f 1 | sort | uniq -u | shuf
  fi
}

scan() {
  [[ -z "$NOSCAN" ]] && echo */* | tr ' ' '\n' > $start_dir/.listen_all || debug "Skipping scan"
}

recent() {
  scan
  # The great 2049 problem.
  # It will not be global environmental collapse.
  # NO! It will be this bash line.
  local first=$(grep -m 1 "20[2-4][0-9]" .listen_done)
  local first_date=${first##* }
  local days=$(( ($(date +%s) - $(date --date=$first_date +%s)) / 86400 ))

  grep "20[2-4][0-9]" .listen_done | awk ' { print $NF } ' | sort | uniq -c
  local ttl=$(wc -l .listen_all | awk ' { print $1 }').0
  local done=$(wc -l .listen_done | awk ' { print $1 }').0
  wc -l .listen*

  perl << END
    print 100 * $done / $ttl . "%\n";
    print "Listen:   " . $done / $days . "/day\n";
    print "Download: " . $ttl / $days . "/day\n";
END

  du -sh
}

_get_urls() {
  $YTDL $SLEEP_OPTS \
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
  
  if [[ -z "$NOUNDO" ]]; then
    _mkdir $UNDODIR/"$path"

    mv "$path"/* $UNDODIR/"$path"
  else
    debug "Bypassing undo and deleting"
    rm "$path"/*
  fi

  echo "$1" > "$path"/no
}

unpurge() {
  _rm "$1"/no 
  [[ -e $UNDODIR/"$1" ]] && mv $UNDODIR/"$1"/* "$1"
  sed -i "/${1/\//.}/d" $start_dir/.listen_done
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
    curl -Ls $(resolve "$1") > "$tmp/$PAGE"
    if [[ $( stat -c %s "$1/$PAGE" ) -lt $( stat -c %s "$tmp/$PAGE" ) ]]; then
      mv "$tmp/$PAGE" "$1/$PAGE"
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
  PLAYLIST_DBG=$tmp/playlist-interim:$(_stub "$2"):$(date +%s)
  local failed=
  local tomatch=
  local matched=
  local path="$2"

  touch "$path/$PLAYLIST"

  if [[ -z "$NONET" ]]; then
    {
      echo "cd '$2'" > $PLAYLIST_DBG

      #$SLEEP_OPTS \
      $YTDL \
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

  [[ -n "$failed" ]] && status "Look in $PLAYLIST_DBG\n"
}

_info_section()  {
  local count=$(echo "$2" | wc -l)
  headline 2 "$count $1"
  echo "$2"
}

_info () {
  local path="$1"
  local url=$(resolve "$path")
  local reldate="$(grep -m 1 -Po '((?<=release[sd] )[A-Z][a-z]+ [0-9]{1,2}, 20[0-9]{2})' "$path/$PAGE" )"
  local matcher=
  _tabs

  # If we were passed additional arguments then this will
  # tell us a full path of where we can find this.
  [[ -n "$2$3" ]] && path=$(dirname "$2/$3")

  {
    dldate=$(stat -c %w "$path/$PAGE")
    [[ $dldate == '-' ]] && dldate=$(stat -c %y "$path/$PAGE")

    info "Released\t$(date --date="$reldate" -I)"
    info "Downloaded\t$(echo $dldate | cut -d ' ' -f 1 )"

    [[ $url =~ 'album' ]] && matcher='track-title' || matcher='trackTitle'

    _info_section "Tracks"      "$(cat "$path/$PAGE" | tr '\n' ' ' | grep -Po '((?<='$matcher'">).*?(?=<))' | sed -E 's/^\s*//g' | awk ' { print FNR". "$0 } ')"
    _info_section "Files"       "$(cd "$path"; ls -l *mp3)" 
    _info_section "PLS entries" "$(cat "$path/playlist.m3u")"

    headline 2  $url
    info        $path
  } | sed -E 's/^([^\t])/\t\1/'

  echo
}

_ytdl () {
  if [[ -z "$NONET" ]]; then
    local url="$1"
    local path="$2"

    $YTDL $SLEEP_OPTS \
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

_repl() {
  while [[ -z "$NOPROMPT" && -z "$skipprompt" ]]; do 
    read -p "[[1m$i[0m] " -e n
    history -s "$n"

    [[ $n == 'i' ]] && _info "$i"

    if [[ $n == '?' ]]; then
      headline 1 "Keyboard commands" 
      { cat <<- ENDL
      ?       - This help page
      3,4,5   - Rate
      p       - Purge (delete)
      un      - Unpurge
      dl      - Download the files
      dlm     - Download manually
      dlp     - Download just the playlist
      g       - Go to a path
      i       - Info on the release
      l       - List the files
      o       - Xdg-open the URL
      r       - Repeat
      r nopl  - Repeat (ignore playlist)
      s       - Skip 
      x       - Exit

      ao      - Set audio out   [$ao]
      b       - Set start time  [$start_time]
      filter  - Set filter      [$filter]

      pl      - Toggle playlist     [${STR[${NOPL:-0}]}]
      net     - Toggle network      [${STR[${NONET:-0}]}]
      score   - Toggle scoring      [${STR[${NOSCORE:-0}]}]
      prompt  - Toggle prompt       [${STR[${NOPROMPT:-0}]}]
      debug   - Toggle debug        [${STR[${DEBUG:-1}]}]
      scan    - Toggle rescan       [${STR[${NOSCAN:-1}]}]
      backup  - Toggle purge backup [${STR[${NOUNDO:-0}]}]

      list    - List things in filter

      !       - Do a \$SHELL at the file directory
      source  - Reload lib

ENDL
    } | sed 's/^\s*/\t\t/g';


    elif [[ ${n:0:1} == 'g' ]]; then
      direct=${n:2}
      n="s"
      hr
      break
    elif [[ ${n:0:2} == 'un' ]]; then
      path=${n:3}
      status "Unpurging $path"
      unpurge $path
      
    elif [[ ${n:0:2} == 'ao' ]]; then
      ao=${n:3}
      status "Setting audio out to '$ao'"
      [[ -e $DIR/prefs.sh ]] && sed -Ei 's/ao=.*/ao='$ao'/g' $DIR/prefs.sh

    elif [[ ${n:0:2} == 'b ' ]]; then
      start_time=${n:2}
      status "Setting start time to $start_time"

    elif [[ "$n" == 'l' ]]; then
      if [[ -s "$m3u" ]]; then
        headline 1 "playlist" 
        cat $m3u | sed 's/^/\t\t/'
      fi

      headline 1 "files"
      ls -l "$i" | sed 's/^/\t\t/'
      echo
    elif [[ "$n" == 'backup' ]]; then
      [[ -z "$NOUNDO" ]] && NOUNDO=1 || NOUNDO=
      status "Backup ${STR[${NOUNDO:-0}]}"

    elif [[ "$n" == 'scan' ]]; then
      [[ -z "$NOSCAN" ]] && NOSCAN=1 || NOSCAN=
      status "Rescanning ${STR[${NOSCAN:-0}]}"

    elif [[ "$n" == 'score' ]]; then
      [[ -z "$NOSCORE" ]] && NOSCORE=1 || NOSCORE=
      status "Scoring ${STR[${NOSCORE:-0}]}"

    elif [[ "$n" == 'net' ]]; then
      [[ -z "$NONET" ]] && NONET=1 || NONET=
      status "Network ${STR[${NONET:-0}]}"

    elif [[ "$n" == 'prompt' ]]; then
      [[ -z "$NOPROMPT" ]] && NOPROMPT=1 || NOPROMPT=
      status "Prompt ${STR[${NOPROMPT:-0}]}"

    elif [[ "$n" == 'pl' ]]; then
      [[ -z "$NOPL" ]] && NOPL=1 || NOPL=
      status "Playlist ${STR[${NOPL:-0}]}"

    elif [[ "$n" == 'debug' ]]; then
      if [[ -z "$DEBUG" ]]; then 
        DEBUG=0 
        echo $PWD
        player_opts="$player_opts_orig $player_opts_dbg"
        set -x
      else
        DEBUG=
        player_opts=$player_opts_orig
        set +x
      fi
      status "Debug ${STR[${DEBUG:-1}]}"

    elif [[ "$n" == 'o' ]]; then
      open_page "$url"

    elif [[ "$n" == 'list' ]]; then
      echo
      echo ${all[@]} | tr ' ' '\n' | sed 's/^\s*/\t/g' | sort
      echo

    elif [[ ${n:0:6} == 'filter' ]]; then
      set_filter ${n:7}
      # this can be turned back on by quitting with a capital Q
      echo $filter
      load_tracks 1
      n=s
      break

    # This is done in mpv-once so that this can reload.
    elif [[ "$n" == 'source' ]]; then
      break

    elif [[ "$n" == '!' ]]; then 
      (
        cd "$i"
        $SHELL
      )
    elif [[ $n == 'dlp' ]]; then 
      (
        status "Downloading playlist"
        get_playlist "$url" "$i"
      )
    elif [[ $n == 'dl' ]]; then 
      get_mp3s "$url" "$i"

    elif [[ $n == 'dlm' ]]; then 
      manual_pull "$url" "$i"

    elif [[ "$n" == 'r nopl' ]]; then
      status "Ignoring playlist"
      nopl=1
      # We treat this like a regular replay
      n=r
    fi
    [[ "$n" =~ ^(x|r|s|[1-5]|p)$ ]] && break
  done
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
  # Details of a path
  
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

get_links() {
  cat .listen_done | grep rating_5 | awk ' { print $1 } ' | while read line; do
    if [[ -e $line/domain ]]; then
      cat $line/domain
    else
      echo $line | awk -F \/ ' { print "https://"$1".bandcamp.com/album/"$2 }' 
    fi
  done
}

get_videos() {
  label=$1
  video_domain="https://bandcamp.23video.com"
  scrape_domain=${1}.bandcamp.com
  if [[ -e $1/domain ]]; then
    scrape_domain=$(< $1/domain)
  fi

  for i in $1/*; do
    release=$(basename $i)
    index=${scrape_domain}/album/${release}
    echo https://$index
    curl -s https://$index | grep data-href | grep -Pio '(?<=")(.*mp4|.*avi|.*mkv|.*flv)(?=")' | while read path
    do
      echo :: $video_domain$path
    done
  done
}
