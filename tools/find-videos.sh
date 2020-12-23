#!/bin/bash

label=$1
video_domain="https://bandcamp.23video.com"
scrape_domain=${1}.bandcamp.com
if [[ -e $1/domain ]]
then
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

