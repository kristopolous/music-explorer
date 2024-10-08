#!/bin/bash

install_bin() {
  local install=${1:-$HOME/bin}
  if [[ ! -d $install ]]; then
    echo "Woops, tell me where to install to."
  fi

  for i in $PWD/tools/*; do
    tool=$(basename $i)
    [[ -e $install/$tool ]] && unlink $install/$tool
    echo $i '$*' > $install/$tool
    chmod +x $install/$tool
  done
}

install_deps() {
  list="lua5.4 yt-dlp pulseaudio lua-posix mpv nodejs gawk bash perl bc"
  read -p "I'm a stupid bash script. I'm going to assume you have a system that uses apt. Just press return if I'm correct > " n

  if [[ -n "$n" ]]; then
    echo "Well that wasn't return ... I was going to install these things: $list"
    exit
  else
    sudo apt -y install $list
  fi
}


install_bin

install_deps
