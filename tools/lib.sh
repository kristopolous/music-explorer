#!/bin/bash

tmp=/tmp/mpvonce
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# What format to look for 
FMT=${FMT:=mp3}

player=mpv
player_opts_orig='--no-cache --no-audio-display --msg-level=cplayer=no --term-playing-msg=\n${media-title} --script='"$DIR"'/mpv-interface.lua --input-ipc-server='"$tmp"'/mpvsocket'
player_opts_dbg="--msg-level=all=debug"
player_opts=$player_opts_orig

BACKUPDIR=$HOME/.mpvonce
UNDODIR=$tmp/undo

# For controlling of remote players 
REMOTE=${REMOTE:=localhost}
REMOTEBASE=${REMOTEBASE:=$PWD}

DEBUG=${DEBUG:=}

# If set, won't try to use the internet
NONET=${NONET:=}

# If set, won't do "expensive" network file system operations 
NOSCAN=${NOSCAN:=}

# If set, don't copy the tracks for an undro of a purge (removal)
NOUNDO=${NOUNDO:=}

# If set, don't try to find or construct ordinal playlists, just play things in the glob-order
NOPL=${NOPL:=}
NOANNOU=${NOANNOU:=}

# What the general downloader tool is (there's a built-in parser with curl as a backup)
YTDL=${YTDL:=yt-dlp}

# What options to pass it
FORMAT="-f mp3-128"

# These are finer options for scraping that tries to not be too greedy
SLEEP_MIN=4
SLEEP_MAX=15
SLEEP_OPTS="--max-sleep-interval $SLEEP_MAX --min-sleep-interval $SLEEP_MIN"

# We can optimize things if we assume there's no such things as a playlist that
# points to URLS that expire
REMOTEPL=

PLAYLIST=playlist.m3u
PLAYLIST_DBG=
PAGE=page.html
STOPFILE=$tmp/mpvstop
start_dir=$( pwd )
direct=

# some simple things first.
_rm ()  { [[ -e "$1" ]] && rm "$1"; }
_mkdir(){ [[ -e "$1" ]] || mkdir -p "$1"; }
_tabs() { tabs 2,+4,+2,+10; }
_stub() { echo "$1" | tr '/' ':'; }
_warn()  { echo -e "\n\t$1\n"; }
info()  { echo -e "\t$1"; }
debug() { [[ -n "$DEBUG" ]] && echo -e "\t$1"; }
purge() { album_purge "CLI" "$1"; }
hr()    { echo; printf '\xe2\x80\x95%.0s' $( seq 1 $(tput cols) ); echo; }
quit()  { echo "$1"; exit; }
check_for_stop() { [[ -e $STOPFILE && -z "$IGNORESTOP" ]] && quit "Stopping because $STOPFILE exists"; }
stop() { touch $STOPFILE; echo "Unstop by running $(basename $0) unstop"; }
unstop() { rm $STOPFILE; echo "Unstopped"; }

[[ -e $DIR/prefs.sh ]] && . $DIR/prefs.sh || debug "Can't find $DIR/prefs.sh"

_mkdir "$tmp"
if [[ ! -p "$tmp"/cmd_sock ]]; then
  rm -f "$tmp"/cmd_sock 
  mkfifo "$tmp"/cmd_sock
fi

function finish {
  history -w $tmp/readline-history
  exit
}

scan()  { 
  if [[ -z "$NOSCAN" ]]; then
    echo */* | tr ' ' '\n' > $tmp/.listen_all
    if [[ -s $tmp/.listen_all ]]; then 
      cp $tmp/.listen_all $start_dir/.listen_all
    else 
      info "Unable to create playlist scan"
    fi
  else 
    debug "Skipping scan"; 
  fi
}

ardy_serve() {
  [[ -e $tmp/ardy_socket ]] && rm $tmp/ardy_socket
  mkfifo $tmp/ardy_socket
  dev=/dev/ttyUSB*
  stty -F $dev 9600
  exec 3<> $dev
  while [ 0 ]; do
    cat $tmp/ardy_socket | tee -a $tmp/cmd | tee > $dev
    echo "]" >> $tmp/cmd
    sleep 0.01
  done
}

breaker() {
  if [[ ! -e $tmp/breaker.mp3 ]]; then 
    for freq in 660 1 500; do
      ffmpeg -loglevel quiet -y -f lavfi -i "sine=frequency=$freq:duration=0.05"  -af "volume=-5dB" -c:a pcm_s16le -f wav $tmp/out-$ix.wav
      (( ix++ ))
    done
    ffmpeg -safe 0 -loglevel quiet -f concat -i <(ls -v1 $tmp/out-*.wav | sed -e 's/^/file /g') -y $tmp/breaker.mp3
  fi
  $player --ao=$ao $player_opts -really-quiet $tmp/breaker.mp3
}

ardy_stat() {
  {
    case $1 in
      [123] )
        printf "$1%-31s" "$2" 
        ;;
      T )
        printf "$1%-31s" "$2:$3" 
        ;;
      * )
        printf "$1$2"
        ;;
    esac
  } > $tmp/ardy_socket
}

announce() {
  [[ -n "$NOANNOU" ]] && echo "$*" | aosd_cat -p 2  -n "Noto Sans Condensed ExtraBold 150" -R white -f 1000 -u 15000 -o 2000 -x -20 -y 20 -d 50 -r 190 -b 216 -S black -e 2 -B black -w 3600 -b 200&
  IFS="-"
  read -ra tp <<< "$@"
  printf "1%-32s2%-32s" "${tp[0]}" "${tp[1]}" > $tmp/ardy_socket
  unset IFS
}

headline() {
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
    [[ ! -d "$i" ]] && continue

    if [[ -e "$i"/album-art.jpg ]]; then 
      echo " ✓     $i"
    elif [[ -e "$i"/no-album-art.jpg ]] ; then
      echo "   ✗   $i"
    else

      album=$(resolve $i)

      url=$(curl -Ls $album | grep -A 4 'tralbumArt' | grep popupImage | grep -Po 'https:.*[jp][pn]g')
      if [[ -n "$url" ]]; then
        curl -so $i/album-art.jpg $url 
      else
        url="404"
        touch "$i"/no-album-art.jpg
      fi
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
  topl=$start_dir/.listen_all

  if [[ ! -e $topl ]]; then
    find . -mindepth 2 -maxdepth 2 -type d | sed s'/^..//' | shuf
  else
    if [[ -n "$NOSCORE" ]]; then
      $cmd $start_dir/.listen_all | cut -d ' ' -f 1 | shuf
    else
      $cmd $start_dir/.listen_all $start_dir/.listen_done | cut -d ' ' -f 1 | sort | uniq -u | shuf
    fi
  fi
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
  local ttl=$(wc -l < .listen_all).0
  local done=$(wc -l < .listen_done).0
  wc -l .listen*

  perl << END
    print 100 * $done / $ttl . "%\n";
    print "Listen:   " . $done / $days . "/day\n";
    print "Download: " . $ttl / $days . "/day\n";
END

  du -sh
}

_get_urls() {
  echo $DIR/ytdl2m3u.awk;
  $YTDL $SLEEP_OPTS \
    --get-duration --get-filename -g $FORMAT -- "$1" \
    | tee $tmp/${2//\//:} \
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

    mv "$path"/* $UNDODIR/"$path" 2> /dev/null
  else
    debug "Bypassing undo"
    rm "$path"/*
  fi

  if [[ ! -e "$path"/no ]]; then
    echo "$1" > "$path"/no
  fi
}

unpurge() {
  [[ -e $UNDODIR/"$1" ]] && mv $UNDODIR/"$1"/* "$1"
  _rm "$1"/no 
  sed -i "/${1/\//.} /d" $start_dir/.listen_done
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
    ls -1 -- *.{$FMT,ogg,m4a,flac,aiff,wav} > $PLAYLIST 2> /dev/null
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
    if [[ -e "$tmp/$PAGE" && $( stat -c %s "$1/$PAGE" ) -lt $( stat -c %s "$tmp/$PAGE" ) ]]; then
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
  
    /bin/bash $PLAYLIST_DBG | grep $FMT | sed -E 's/^/.\//g' > "$path/$PLAYLIST"
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

_trinfo() {
  local path=$(dirname "$1")
  local len=$2
  local url=$(resolve "$path")
  local art=$(grep -A 4 'tralbumArt' "$path/page.html" | grep popupImage | grep -Po 'https:.*[jp][pn]g')
  # blank line record seperator
  # otherwise everything begins with a space
cat >> .share_list << END 
 $(date +%s)
 $1
 $url
 $art
 $(stat -c %s "$1")
 $len

END
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
    _info_section "Files"       "$(cd "$path"; ls -l *.{$FMT,ogg,m4a,flac,aiff,wav} 2> /dev/null)" 
    _info_section "URLs"        "$(for x in $path/*.$FMT; do _trackpath "$x"; done)"
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

_parse() {
  _fn=$1
  shift
  _arg=$1
}

_url() {
  local domain
  local release
  local label=$( dirname "$1" )
  [[ -e "$label/domain" ]] && domain=$(< "$label/domain" ) || domain=${label}.bandcamp.com
  release=$( basename "$1" )
  echo "https://$domain/album/$release"
}

toopus() {
  set -e
  in="$*"

  if [[ -d "$in" ]]; then
    for i in "$in"/*.mp3; do
      toopus "$i" &
    done
    wait $(jobs -p)
    exit
  fi

  out="${in/.mp3/.opus}"
  if [[ ! -s "$out" ]] ; then
    ffmpeg -nostdin -loglevel quiet -i "$in" -write_xing 0 -id3v2_version 0 -vn -c:a libopus -b:a 15000 "$out" 
  fi
}

tom5a() {
  set -e
  in="$*"
  
  if [[ -d "$in" ]]; then
    for i in "$in"/*.mp3; do
      tom5a "$i" &
    done
    wait $(jobs -p)
    exit
  fi

  out="${in/.mp3/.m5a}"
  if [[ ! -s "$out" ]] ; then
    ffmpeg -nostdin -loglevel quiet -i "$in" -write_xing 0 -id3v2_version 0 -vn -ac 2 -f wav - | fdkaac -S -b 32000 -p 29 /dev/stdin -o "$out"
  fi
}

_trackpath() {
  # first we have to extract the title
  local path="$@"
  local base=$(dirname "$path")
  local fname=$(basename "$path")
  local title=$(echo "$fname" | sed -E 's/ - (.*)/\/\1/g;s/-[0-9]+.mp3//g;' | cut -d \/ -f 2)
  <$base/page.html tr '\n' ' ' | grep -Po '(?<=script type="application.ld.json">)(.*?)(?=</scr)'  | jq ".track.itemListElement[] |select(.item.name==\"$title\")|.item[\"@id\"]" | tr -d '"'
}

_repl() {
  while [[ -z "$NOPROMPT" && -z "$skipprompt" ]]; do 
    echo -n "[$i] " 
    n=$( $DIR/magic-read.py "$tmp/cmd_sock"   )
    history -s "$n"
    _parse $n

    if [[ $n == '?' ]]; then
      headline 1 "Keyboard commands" 
      { cat <<- ENDL
      ?       - This help page
      3,4,5   - Rate
      e       - Eval
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
      r no    - Repeat (ignore playlist)
      s       - Skip 
      x       - Exit

      remote  - Set remote server [$REMOTE]
      base    - Set remote base   [$REMOTEBASE]
      fmt     - Set the format    [$FMT]
      ao      - Set audio out     [$ao]
      b       - Set start time    [$start_time]
      filter  - Set filter        [$filter]

      pl      - Toggle playlist     [${STR[${NOPL:-0}]}]
      net     - Toggle network      [${STR[${NONET:-0}]}]
      score   - Toggle scoring      [${STR[${NOSCORE:-0}]}]
      prompt  - Toggle prompt       [${STR[${NOPROMPT:-0}]}]
      debug   - Toggle debug        [${STR[${DEBUG:-1}]}]
      scan    - Toggle rescan       [${STR[${NOSCAN:-1}]}]
      undo    - Toggle purge backup [${STR[${NOUNDO:-0}]}]
      anno    - Toggle announce     [${STR[${NOANNOU:-0}]}]

      list    - List things in filter

      !       - Do a \$SHELL at the file directory
      source  - Reload lib

ENDL
    } | sed 's/^\s*/\t\t/g';


    elif [[ "$_fn" == 'e' ]]; then
      torun=${n:2}
      status "-> Running $torun"
      eval "$torun"
    elif [[ "$_fn" == 'g' ]]; then
      # If I go there explicitly then ignore the n
      direct="$_arg"
      n="s"
      hr
      break
    elif [[ "$_fn" == 'un' ]]; then
      status "Unpurging $_arg"
      unpurge "$_arg"
      
    elif [[ "$_fn" == "fmt" ]]; then
      FMT=$_arg
      status "Format -> $_arg"
    elif [[ "$_fn" == "remote" ]]; then
      REMOTE=$_arg
      status "Server -> $_arg"
    elif [[ "$_fn" == "base" ]]; then
      REMOTEBASE="$_arg"
      status "Base -> $_arg"
    elif [[ "$_fn" == 'ao' ]]; then
      ao=${n:3}
      status "Setting audio out to '$ao'"
      [[ -e $DIR/prefs.sh ]] && sed -Ei 's/ao=.*/ao='$ao'/g' $DIR/prefs.sh

    elif [[ "$_fn" == "b" ]]; then
      status "Setting start time to $_arg"
      start_time=$_arg

    elif [[ "$_fn" == 'l' ]]; then
      if [[ -s "$m3u" ]]; then
        headline 1 "playlist" 
        cat $m3u | sed 's/^/\t\t/'
      fi

      headline 1 "files"
      ls -l "${_arg:-$i}" | sed 's/^/\t\t/'
      echo
    elif [[ "$n" =~ (anno|undo|scan|score|net|prompt|pl) ]]; then 
      local base=1
      flag=NO${n^^}
      eval $flag'=${base:$'$flag}
      status "${n^} ${STR[${!flag:-0}]}"

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

    elif [[ "$_fn" == 'filter' ]]; then
      set_filter ${n:7}
      # this can be turned back on by quitting with a capital Q
      echo $filter
      load_tracks 1
      n=s
      break

    elif [[ "$n" == '!' ]]; then 
      (
        cd "$i"
        $SHELL
        reset
      )
    elif [[ "$_fn" == 'dlp' ]]; then 
      (
        [[ -n "$_arg" ]] && t_url="$(_url "$_arg")" || t_url="$url"
        status "Downloading playlist"
        get_playlist "$t_url" "$i"
      )

    elif [[ "$n" == 'r no' ]]; then
      status "Ignoring playlist"
      nopl=1
      # We treat this like a regular replay
      n=r
    else
      [[ -n "$_arg" ]]          && t_url="$(_url "$_arg")" || t_url="$url"
      [[ "$_fn" == 'list' ]]    && echo ${all[@]} | tr ' ' '\n' | sed 's/^\s*/\t/g' | sort
      [[ "$_fn" == 'i' ]]       && _info "${_arg:-$i}"
      [[ "$_fn" == 'dl' ]]      && get_mp3s "$t_url" "${_arg:-$i}"
      [[ "$_fn" == 'dlm' ]]     && manual_pull "$t_url" "${_arg:-$i}"
      [[ "$_fn" == 'source' ]]  && break
      [[ "$_fn" == 'o' ]]       && open_page "$t_url"
    fi
    # This can fix when mount point hangups and reconnects can occur
    # and comes at a very little cost otherwise
    cd "$start_dir"

    [[ "$n" =~ ^(x|r|s|[1-5]|p)$ ]] && break
  done
}

manual_pull() {
  local path="$2"
  local base=$( echo $1 | awk -F[/:] '{print $4}' )
  local track=

  echo " ▾▾ Manual Pull "

  for track in $(curl -Ls "$1" | grep -Po '((?!a href=\")/track\/[^\&"]*)' | sed -E s'/[?#].*//' | sort | uniq); do
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

single_album() {
  echo "$1" > domain
  get_mp3s "$1" "$(pwd)"
  get_page "$(pwd)"
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

    echo -e "$release_url\n\n$label // $release\n${track/-[0-9]*.mp3/}"
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

