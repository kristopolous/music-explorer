#!/usr/bin/python3
import sys,os,subprocess,select,configparser
import pdb, time, logging, io
import select 

config = configparser.ConfigParser()

if os.path.exists('midiconfig.ini'):
  config.read('midiconfig.ini')
  
controlMapping = { }
optionMap = {}
valueMap = {}
lastValueMap = {}
todoMap = {}
audioDev = False

for key in config['config']:
  optionMap[key] = config['config'][key]

for key in config['mappings']:
  code = int(config['mappings'][key])
  controlMapping[code] = key

logging.basicConfig(level=getattr(logging, (os.getenv('LOG') or 'info').upper(), None))

usbDevice = os.popen((
  '|'.join([
    'pactl list sinks',
    'grep -C 4 {}',
    'grep -E "^S"',
    'cut -d "#" -f 2'
  ])).format(optionMap.get('bt') or 'MPOW')).read().strip()

lastval = False
ifilter = ''

if optionMap.get('device'):
  ifilter = "grep '{}'".format(optionMap.get('device'))
else:
  ifilter = 'tail -1'

cmd = "amidi -l | %s | awk ' { print $2 }'" % (ifilter)
logging.info(cmd)

deviceNumber = os.popen(cmd).read().strip()
if not deviceNumber or deviceNumber == 'Device':
  logging.warning("{} failed to find devices!".format(cmd))
  logging.warning(os.popen("amidi -l").read().strip())
  sys.exit(-1)

logging.info("Using Device #{}".format(deviceNumber))

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
  stuff = io.StringIO()
  stuff.write(what)
  [ stuff.write(" [{:>02x} {}]".format(num, num)) for num in bList ]
  stuff.write(' ')
  logging.debug(stuff.getvalue())

def active():
  global audioDev
  audioDev = os.popen('|'.join([
    'pacmd list-sinks',
    'grep -B 4 RUNNING',
    'grep index',
    "awk ' { print $NF } '",
    'head -1'
  ])).read().strip()

sign = lambda x: '-' if x < 0 else '+'

active()

###
# Main loop
###
last_ts = time.time()
while True:
  readable, blah0, blah1 = select.select([ps.stdout.fileno()], [], [], 1)

  if len(readable) == 0 or time.time() > last_ts + .14:
    last_ts = time.time()

    for v in todoMap.values():
      logging.info(v)
      os.system("{}&".format(v))

    todoMap = {}

  if len(readable) == 0:
    continue

  output = ps.stdout.read(1)

  if len(output) == 0:
    logging.warning("Cannot read the stdin")
    break

  logging.debug(valueMap)
  if not output:
    continue

  num = int.from_bytes(output, byteorder='little')
  nibHigh = num & 0xf0

  logging.debug(" {:>02x} ".format(num))

  if nibHigh not in msgList:
    logging.warning(" Unknown channel message: {}".format(num))
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
        cmd += ";pactl set-sink-volume {} {}".format(audioDevice, value * 512)

      logging.info(cmd)

    if todo == 'tabs':
      if lastValueMap.get('tabs'):
        if lastValueMap['tabs'] / 3 > valueMap['tabs'] / 3:
          todoMap['tab'] = "chrome-tab next"
        else:
          todoMap['tab'] = "chrome-tab prev"


    elif todo and (todo[:2] == 'bw' or todo[:2] == 'fw'):
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

      todoMap['screen'] = "night {}".format(' '.join(params))

    elif todo in ['prev','next','pauseplay'] and value == 0:
      cmd = "./ipc-do.js {}".format(todo)

    elif todo in cmdMap:
      if value == 0:
        cmd = "tmux send-keys -t mpv-once '{}'".format(cmdMap[todo])

    else:
      pass

    if cmd:
      logging.info(cmd)
      os.popen(cmd)
