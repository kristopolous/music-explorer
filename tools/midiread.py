#!/usr/bin/python3
import sys,os,subprocess,select

device = False
lastval = False
cmd = "amidi -p hw:2,0,0 -r /dev/stdout"
ps = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
ix = 0
cmdMap = {
  59: 'q',
  62: '>',
  61: '<'
}

while True:
  output = ps.stdout.read(1)

  if output == '' and process.poll() is not None:
    break
  if output:
    num = int.from_bytes(output, byteorder='little')
    sys.stdout.write(" {:>3}".format(num))
    if ix % 3 == 2:
      sys.stdout.write("\n")

    sys.stdout.flush()

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

      elif device in cmdMap:
        if num == 0:
          cmd = "tmux send-keys -t mpv-once '{}'".format(cmdMap[device])

      else:
        pass
        #print("Unrecognized")

      if cmd:
        os.popen(cmd)

  ix += 1
