#!/usr/bin/python3
import sys,os

device = False
lastval = False
with open('midi', 'rb') as f:
  ix = 0
  while True:
    b = f.read(1)
    num = int.from_bytes(b, byteorder='little')

    if ix % 3 == 1:
      device = num

    if ix % 3 == 2:
      cmd = False
      if device == 16:
        cmd = 'amixer -D pulse sset Master {}%'.format( int(100 * num / 127))

      elif device == 17:
        if lastval: 
          if lastval > num:
            cmd = "tmux send-keys -t mpv-once 'Left'"
          else:
            cmd = "tmux send-keys -t mpv-once 'Right'"

        lastval = num

      elif device == 59:
        if num == 0:
          cmd = "tmux send-keys -t mpv-once 'q'"

      elif device == 62:
        if num == 0:
          cmd = "tmux send-keys -t mpv-once '>'"

      elif device == 61:
        if num == 0:
          cmd = "tmux send-keys -t mpv-once '<'"

      else:
        print("Unrecognized: {} {}".format(device, num))

      if cmd:
        os.popen(cmd)

    ix += 1
