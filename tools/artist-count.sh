#!/bin/bash
(
  for release in $(cat .listen_done| grep rating_5 | awk ' { print $1 } '); do
    for track in $release/*mp3; do
      echo $track
      id3v2 -R "$track" 
    done
  done
) | grep TPE2 | sort | sed -E s'/TPE[12]:\s*//g' | uniq -c | sort -n | uniq
