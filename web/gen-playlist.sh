#!/bin/bash
 
gen_playlist() {
  truncate --size 0 playlist.txt
  grep rating_5 /raid/mp3/label/.listen_done | sort | cut -f 1 -d ' ' | while read i
  do
    ls /raid/mp3/label/$i/*.mp3 >> playlist.txt
  done
}

as_csv() {
  truncate --size 0 playlist.db
  awk -F '/' ' { print FNR",\""$5"\",\""$6"\",\""$7"\",\""$0"\"" } ' playlist.txt > /tmp/playlist.csv
  sqlite3 playlist.db << ENDL
  create table tracks(
    id INTEGER PRIMARY KEY,
    label text,
    release text,
    track text,
    path text);
.mode csv
.import /tmp/playlist.csv tracks
create index label_name on tracks(label);
create index release_name on tracks(release);
ENDL
  

}

as_csv
