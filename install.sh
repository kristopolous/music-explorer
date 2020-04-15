#!/bin/bash
for i in $PWD/tools/*; do
  unlink $HOME/bin/$(basename $i)
  ln -s $i $HOME/bin
done
