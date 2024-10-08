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
  list="lua5.4 pulseaudio lua-posix mpv nodejs gawk bash perl bc"
  read -p "I'm a stupid bash script. I'm going to assume you have a system that uses apt. Just press return if I'm correct > " n

  if [[ -n "$n" ]]; then
    echo "Well that wasn't return ... I was going to install these things: $list"
    exit
  else
    sudo apt -y install $list
  fi

  cat <<ENDL
  Alright the last thing you need is a fork of youtube-dl. I use yt-dlp, which you need from github (https://github.com/yt-dlp/yt-dlp). You can also use something else:

    * either have a prefs.sh file wher you run mpv-once at with an override of the YTDL variable OR
    * start things like "$ YTDL=youtube-dl album-get" OR
    * edit lib.sh yourself and change the YTDL to be whatever you want.

  If things don't work you can invoke things with DEBUG=1 like so:

  $ DEBUG=1 mpv-once 

  or whatever and you'll get more then what you need.
ENDL
}


install_bin

install_deps
