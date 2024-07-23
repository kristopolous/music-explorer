#!/bin/bash
music_dir=/raid-real/mp3/label/
 
gen_playlist() {
  truncate --size 0 playlist.txt
  grep rating_5 "$music_dir"/.listen_done | sort | cut -f 1 -d ' ' | while read i
  do
    ls "$music_dir"/$i/*.mp3 >> playlist.txt
  done
}

import_songs() {
  set -e
  # get just the paths
  grep rating_5 "$music_dir"/.listen_done | sort | cut -f 1 -d ' ' | uniq | awk '{ print "/raid-real/mp3/label/"$0 }' | while read remotepath; do
    localpath="$(echo "$remotepath" | sed "s/raid-real/raid/")"
    [[ -d "$localpath" ]] || mkdir -p "$localpath"
    cp --preserve=timestamps -ur "$remotepath"/* "$localpath"
    echo "$remotepath -> $localpath"
  done

  sed -i 's/raid-real/raid/g' playlist.txt
}

import() {
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

gen_playlist
import_songs
#create_db
import
