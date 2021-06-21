#!/bin/bash

truncate --size 0 playlist.txt
grep rating_5 /raid/mp3/label/.listen_done | sort | cut -f 1 -d ' ' | while read i
do
  ls /raid/mp3/label/$i/*.mp3 >> playlist.txt
done
