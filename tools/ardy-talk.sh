#!/bin/bash
dev=/dev/ttyUSB0
exec 3<> $dev
sleep 2
#brightness=${1:-2}
#bc=$(date "+obase=16;4096+(%H*60+%M)")
printf "V\xc01%-16s2%-16s" "Coppice Halifax" "Tra 1.2" > $dev
exec 3<&-;
