#!/usr/bin/python3
import sys,os,subprocess,select,configparser
import pdb, time
import select 
from pprint import pprint

config = configparser.ConfigParser()

if os.path.exists('midiconfig.ini'):
  config.read('midiconfig.ini')
  
controlMapping = { }
optionMap = {}
valueMap = {}
lastValueMap = {}
todoMap = {}

for key in config['config']:
  optionMap[key] = config['config'][key]

for key in config['mappings']:
  code = int(config['mappings'][key])
  controlMapping[code] = key

"""    
pprint(controlMapping)

sys.exit()
"""

usbDevice = os.popen('pactl list sinks | grep -C 4 MPOW | grep -E "^S" | cut -d "#" -f 2').read().strip()

lastval = False
ifilter = ''

if optionMap.get('device'):
  ifilter = "grep '{}'".format(optionMap.get('device'))
else:
  ifilter = 'tail -1'

cmd = "amidi -l | %s | awk ' { print $2 }'" % (ifilter)
print(cmd)

deviceNumber = os.popen(cmd).read().strip()
if not deviceNumber or deviceNumber == 'Device':
  print("{} failed to find devices!".format(cmd))
  print(os.popen("amidi -l").read().strip())
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
  'quit': 'q'
}

def get(count) :
  res = [ int.from_bytes(ps.stdout.read(1), byteorder='little') for x in range(count) ]
  return res if count > 1 else res[0]

def dbg(what, bList):
  sys.stdout.write(what)
  [ sys.stdout.write(" [{:>02x} {}]".format(num, num)) for num in bList ]
  sys.stdout.write(' ')

sign = lambda x: '-' if x < 0 else '+'

def process(valueMap):
  for control,value in valueMap.items():
    todo = controlMapping.get(control)
    cmd = None

    direction = int((value - 64) / 8)

    if direction > 0:
      direction -= 1

    elif direction < 0:
      direction += 1

    if todo:
      print(todo, value, direction)

    if todo == 'volume' and direction != 0:

      mult = 1
      amixerDirection = direction * mult
      pactlDirection = direction * mult * 655

      cmd = 'amixer -D pulse sset Master {}%{}'.format( abs(amixerDirection), sign(direction) )
      if usbDevice:
        cmd += ";pactl set-sink-volume {} {}{}".format(usbDevice, sign(direction), abs(pactlDirection))

    elif todo == 'seek' and direction != 0:
      seekDirection = direction * 10
      cmd = "./ipc-do.js forward {}".format(seekDirection)

    if cmd:
      print(cmd)
      os.popen(cmd)

###
# Main loop
###
last_ts = time.time()
while True:
  readable, blah0, blah1 = select.select([ps.stdout.fileno()], [], [], 1)

  if len(readable) == 0 or time.time() > last_ts + .14:
    last_ts = time.time()
    process(valueMap)

    for v in todoMap.values():
      print(v)
      os.system(v)

    todoMap = {}

  if len(readable) == 0:
    continue

  output = ps.stdout.read(1)

  if len(output) == 0:
    print("Cannot read the stdin")
    break

  print(valueMap)
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
    lastValueMap[control] = valueMap.get(control)
    valueMap[control] = value

    cmd = False
    todo = None
    if control in controlMapping:
      todo = controlMapping[control]
      lastValueMap[todo] = valueMap.get(todo)
      valueMap[todo] = value
      # print(todo, control, controlMapping)

    if todo == 'local_volume_abs':
      cmd = 'amixer -c 0 sset Master {}%'.format( int(100 * value / 127))

    elif todo == 'pulse_volume_abs':
      cmd = 'amixer -D pulse sset Master {}%'.format( int(100 * value / 127))
      if usbDevice:
        cmd += ";pactl set-sink-volume {} {}".format(usbDevice, value * 512)

      print(cmd)

    """
    elif todo == 'seek':
      if lastval: 
        if lastval > value:
          cmd = "./ipc-do.js back"
        else:
          cmd = "./ipc-do.js forward"

      lastval = value
    """

    if todo == 'tabs':
      if lastValueMap.get('tabs'):
        if lastValueMap['tabs'] / 3 > valueMap['tabs'] / 3:
          todoMap['tab'] = "chrome-tab next"
        else:
          todoMap['tab'] = "chrome-tab prev"


    elif todo[:2] == 'bw' or todo[:2] == 'fw':
      amount = int(todo[2:])
      dir = 'back' if todo[:2] == 'bw' else 'forward'
      cmd = "./ipc-do.js {} {}".format(dir, amount)

    elif todo in ['redshift', 'brightness']:
      params = []
      gamma = valueMap.get('gamma') if 'gamma' in valueMap else (.7 * 127)
      if 'redshift' in valueMap:
        redshift = int(12000 * valueMap['redshift'] / 127.0 + 1000)
        params.append("-r {}".format(redshift))

      if 'brightness' in valueMap:
        bright = valueMap['brightness'] / 127.0
        params.append("-b {}".format(bright))

      todoMap['screen'] = "/home/chris/bin/night {}".format(' '.join(params))

    elif todo in ['prev','next','pauseplay'] and value == 0:
      cmd = "./ipc-do.js {}".format(todo)

    elif todo in cmdMap:
      if value == 0:
        cmd = "tmux send-keys -t mpv-once '{}'".format(cmdMap[todo])

    else:
      pass
      #print("Unrecognized")

    if cmd:
      print(cmd)
      os.popen(cmd)
    else:
      sys.stdout.write("\n")

  sys.stdout.flush()


