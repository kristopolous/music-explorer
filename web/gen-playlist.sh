#!/bin/bash
 
gen_playlist() {
  truncate --size 0 playlist.txt
  grep rating_5 /raid/mp3/label/.listen_done | sort | cut -f 1 -d ' ' | while read i
  do
    ls /raid/mp3/label/$i/*.mp3 >> playlist.txt
  done
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
#create_db
import
