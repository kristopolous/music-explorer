#!/bin/bash
music_dir=/raid-real/mp3/label/
 
gen_playlist() {
  truncate --size 0 playlist.txt
  grep rating_5 "$music_dir"/.listen_done | sort | cut -f 1 -d ' ' | while read i
  do
    ls "$music_dir"/$i/*.mp3 >> playlist.txt
  done
}

copy_songs() {
  # get just the paths
  grep rating_5 "$music_dir"/.listen_done | sort | cut -f 1 -d ' ' | uniq | awk '{ print "'$music_dir'"$0 }' | while read remotepath; do
    localpath="$(echo "$remotepath" | sed "s/raid-real/raid/")"
    if [[ ! -d "$localpath" ]];then 
      mkdir -p "$localpath"
      cp --preserve=timestamps -ur "$remotepath"/* "$localpath"
      echo "$remotepath -> $localpath"
    fi
  done

  sed -i 's/raid-real/raid/g' playlist.txt
}

convert_songs() {
  sqlite3 playlist.db "select path from tracks" | while read p; do
    echo $p
    mpv-lib toopus $p
    mpv-lib tom5a $p
  done
}

import_todb() {
  awk -F '/' ' { fuckoff=$0;sub(/-[0-9]*.mp3/, "", $7);print FNR",\""$5"\",\""$6"\",\""$7"\",\""fuckoff"\"" } ' playlist.txt > /tmp/playlist.csv
  {
  sqlite3 playlist.db << ENDL
.mode csv
.import /tmp/playlist.csv tracks
update tracks set created_at = current_timestamp where created_at is null;
ENDL
} >& /dev/null
}

as_csv() {
  truncate --size 0 playlist.db
  sqlite3 playlist.db << ENDL
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
