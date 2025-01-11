#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PATH=$HOME/code/music-explorer/tools/:$PATH
music_dir=/raid-real/mp3/label/
db_dir=$HOME/www/pl
playdb=$db_dir/playlist.db
playtxt=/tmp/playlist.txt
playcsv=/tmp/playlist.csv

start=$(date +%s)
dbg() {
  [[ -n "$INFO" ]] && echo $(( $(date +%s) - start )) "$1"
}
 
gen_playlist() {
  dbg "truncating"
  truncate --size 0 $playtxt
  dbg "recreating"
  grep rating_5 "$music_dir".listen_done | sort | cut -f 1 -d ' ' | while read i
  do
    ls "$music_dir"$i/*.mp3 >> $playtxt
  done
  dbg "playlist done"
}

copy_songs() {
  # get just the paths
  dbg "copying songs"
  grep rating_5 "$music_dir".listen_done | sort | cut -f 1 -d ' ' | uniq | awk '{ print "'$music_dir'"$0 }' | while read remotepath; do
    localpath="$(echo "$remotepath" | sed "s/raid-real/raid/")"
    if [[ ! -d "$localpath" ]];then 
      mkdir -p "$localpath"
      cp --preserve=timestamps -ur "$remotepath"/* "$localpath"
    fi
  done

  dbg "copying done"
  sed -i 's/raid-real/raid/g' $playtxt
}

convert_songs() {
  dbg "converting songs"
  truncate --size 0 conv_update.sql
  local n=0
  sqlite3 $playdb "select path from tracks where converted is not true" > conv_list.txt
  cat conv_list.txt | while read p; do
    if [[ ! -s "$p" ]]; then
      echo "path $p doesn't exist"
    else 
      mpv-lib toopus "$p" &
      pid_opus=$!

      mpv-lib tom5a "$p" &
      pid_m5a=$!

      wait $pid_opus
      wait $pid_m5a

      path_m5a="${p/.mp3/.m5a}"
      path_opus="${p/.mp3/.opus}"

      if [[ -s "$path_m5a" && -s "$path_opus" ]]; then
        (( n++ ))
        echo "update tracks set converted=true where path = \"$p\";" >> conv_update.sql
      else
        echo "Error for $p:"
        echo " - ($path_m5a)"
        echo " - ($path_opus)"
      fi
      if (( n > 80 )); then
        echo ""
        sqlite3 $playdb < conv_update.sql
        truncate --size 0 conv_update.sql
        n=0
      fi
    fi
  done
  sqlite3 $playdb < conv_update.sql
  truncate --size 0 conv_update.sql
  dbg "converting done"
}

import_todb() {
  awk -F '/' ' { fuckoff=$0;sub(/-[0-9]*.mp3/, "", $7);print FNR",\""$5"\",\""$6"\",\""$7"\",\""fuckoff"\"" } ' $playtxt > $playcsv
  {
  sqlite3 $playdb << ENDL
PRAGMA encoding=UTF8;
.mode csv
.import $playcsv tracks
update tracks set created_at = current_timestamp where created_at is null;
ENDL
} >& /dev/null
}

create_db() {
  truncate --size 0 $playdb
  sqlite3 $playdb << ENDL
  create table tracks(
    id INTEGER PRIMARY KEY,
    label text,
    release text,
    track text,
    path text,
    artist text,
    listen integer default 0,
    plays integer default 0,
    up integer default 0,
    down integer default 0,
    duration integer default 0,
    converted boolean default false,
    created_at timestamp default current_timestamp,
    unique(path));
.mode csv
create index label_name on tracks(label);
create index release_name on tracks(release);
ENDL
}

#create_db
gen_playlist
copy_songs
import_todb
convert_songs
