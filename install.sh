#!/bin/bash
install=${1:-$HOME/bin}
if [[ ! -d $install ]]; then
  echo "Woops, tell me where to install to."
fi

for i in $PWD/tools/*; do
  tool=$(basename $i)
  [[ -e $install/$tool ]] && unlink $install/$(basename $i)
  ln -s $i $install
done
