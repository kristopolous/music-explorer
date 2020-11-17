#!/bin/bash

cat .listen_done | grep rating_5 | awk ' { print $1 } ' | while read line; do
  if [[ -e $line/domain ]]; then
    cat $line/domain
  else
    echo $line | awk -F \/ ' { print "https://"$1".bandcamp.com/album/"$2 }' 
  fi
done
