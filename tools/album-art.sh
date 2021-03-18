#!/bin/bash

[[ -z "$DIR" ]] && DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. lib.sh

for i in */*; do
  [[ ! -d $i ]] && continue

  if [[ ! -e $i/no && ! -e $i/album-art.jpg ]] ; then

    album=$(resolve $i)

    url=$(curl -Ls $album | grep -A 4 'tralbumArt' | grep popupImage | grep -Po 'https:.*[jp][pn]g')
    [[ -n "$url" ]] && curl -so $i/album-art.jpg $url
    echo "$url => $album"
  fi
done
