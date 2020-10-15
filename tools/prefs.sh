#!/bin/sh
player=mpv
player_opts="--script=$DIR/quit-on-error.lua "'--term-playing-msg=\n${media-title} --input-ipc-server=/tmp/mpvsocket'
ao=lsa
