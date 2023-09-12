#!/bin/bash
dev=/dev/ttyUSB*
stty -F $dev 9600
exec 3<> $dev
while [ 0 ]; do
  nc -l -p 5000 > $dev
  sleep 0.01
done
