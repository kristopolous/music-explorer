#!/usr/bin/python3
import sys,os,subprocess,select

lastval = False
cmd = "amidi -l | tail -1 | awk ' { print $2 }'"
deviceNumber = os.popen(cmd).read().strip()
if not deviceNumber or deviceNumber == 'Device':
  print("{} failed to find devices!".format(cmd))
  sys.exit(-1)

print("Using Device #{}".format(deviceNumber))

cmd = "amidi -p {} -r /dev/stdout".format(deviceNumber)
ps = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)

msgList = [ 0xC0, 0xB0, 0xF0 ]

class msg:
  control = 0xB0
  program = 0xC0
  system = 0xF0
  eox = 0xF7

cmdMap = {
  59: 'q',
  17: '>',
  18: '<'
}

def get(count) :
  res = [ int.from_bytes(ps.stdout.read(1), byteorder='little') for x in range(count) ]
  return res if count > 1 else res[0]

def dbg(what, bList):
  sys.stdout.write(what)
  [ sys.stdout.write(" [{:>02x}]".format(num)) for num in bList ]

while True:
  output = ps.stdout.read(1)

  if output == '' and process.poll() is not None:
    break

  if not output:
    continue

  num = int.from_bytes(output, byteorder='little')
  nibHigh = num & 0xf0

  sys.stdout.write(" {:>02x} ".format(num))

  if nibHigh not in msgList:
    print(" Unknown channel message: {}".format(num))
    sys.stdout.flush()
    continue

  if nibHigh == msg.system:
    vendor = [get(1)]
    while True:
      nextByte = get(1)
      if nextByte == msg.eox:
        break
      vendor.append(nextByte)
    dbg('vendor', vendor)

  elif nibHigh == msg.program:
    value = get(1)
    dbg('program', [value])

  elif nibHigh == msg.control:
    control, value = get(2)
    dbg('control', [control,value])

    cmd = False
    if control == 0x16:
      cmd = 'amixer -D pulse sset Master {}%'.format( int(100 * value / 127))
      print(cmd)

    elif control == 0x0e:
      if lastval: 
        if lastval > value:
          cmd = "./ipc-do.js back"
        else:
          cmd = "./ipc-do.js forward"

      lastval = value

    elif control in cmdMap:
      if value == 0:
        cmd = "tmux send-keys -t mpv-once '{}'".format(cmdMap[control])

    else:
      pass
      #print("Unrecognized")

    if cmd:
      print(cmd)
      os.popen(cmd)

  sys.stdout.write("\n")
  sys.stdout.flush()


