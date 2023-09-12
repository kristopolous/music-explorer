#!/bin/bash
dev=/dev/ttyUSB*
stty -F $dev 9600
exec 3<> $dev
while [ 0 ]; do
  nc -l -p 5000 | tee -a /tmp/mpvonce/cmd | tee > $dev
  echo >> /tmp/mpvonce/cmd
  sleep 0.01
done
