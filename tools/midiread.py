#!/usr/bin/python3
import sys,os,subprocess,select

device = False
lastval = False
deviceNumber = os.popen("amidi -l | tail -1 | awk ' { print $2 }'").read().strip()
cmd = "amidi -p {} -r /dev/stdout".format(deviceNumber)
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
      control = num

    if ix % 3 == 2:
      cmd = False
      if control == 16:
        cmd = 'amixer -D pulse sset Master {}%'.format( int(100 * num / 127))

      elif control == 17:
        if lastval: 
          if lastval > num:
            cmd = "tmux send-keys -t mpv-once 'Left'"
          else:
            cmd = "tmux send-keys -t mpv-once 'Right'"

        lastval = num

      elif control in cmdMap:
        if num == 0:
          cmd = "tmux send-keys -t mpv-once '{}'".format(cmdMap[control])

      else:
        pass
        #print("Unrecognized")

      if cmd:
        os.popen(cmd)

  ix += 1
