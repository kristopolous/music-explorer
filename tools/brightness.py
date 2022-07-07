#!/usr/bin/python3
#sort -n brightout.list| awk ' { print $2 } ' | xargs -n 1 identify -format "%w%h %d\/%f\n" | grep "12001200" | awk ' { print $2 } '

from PIL import Image, ImageStat
import sys, math, sys
import colorsys, os

width = int(sys.argv[1])

ttl = 0
bucket = [set() for i in range(width)]

def bucket_check(ix, s):
  global bucket,ttl
  if len(bucket[ix]) >= width:
    sys.stderr.write("f")
    return -1
  if s in bucket[ix]:
    sys.stderr.write("c")
    return 0

  sys.stderr.write("\n{:5} Fill bucket {}".format(ttl,ix))
  bucket[ix].add(s)
  ttl += 1
  return 1



def brightness( im_file ):
  im = Image.open(im_file)
  stat = ImageStat.Stat(im)
  r,g,b = stat.mean
  h,s,l = colorsys.rgb_to_hsv(r/255,g/255,b/255)
  #m_r,m_g,m_b = stat.rms

  # brightness is [0..255]

  #brightness = math.sqrt(0.241*(r**2) + 0.691*(g**2) + 0.068*(b**2))
  if l < 0.05 or l > 0.95:
    return None
  
  l -= 0.05
  l *= (1/0.9) 
  #if brightness < 64 or brightness > 192:
  #  return None
  #
  #brightness -= 64

  ix = round(l * width)
  brightness_col = round(l * width * width)

  if s < 0.10 and l > 0.2 and l < 0.9:
    #sys.stderr.write("{:5} {} {} {} {} {} {} {}\n".format(ttl,h,s,l, m_r,m_g,m_b,im_file))
    return None

  added = bucket_check(ix, (brightness_col, h))
  """
  if added == -1:
    if ix > 0:
      added = bucket_check(ix-1, (brightness_col, h))
      if added == 1:
        ix -= 1
    if ix < width and added == -1:
      added = bucket_check(ix+1, (brightness_col, h))
      if added == 1:
        ix += 1
  """ 
  if added == 1:
    return "{} {}".format(ix, h)

  return None
 

for line in sys.stdin:
  if ttl >= width * width:
    sys.exit(0)

  line = line.rstrip()

  try:
    if not os.path.exists(line):
      continue

    res = brightness(line)
    if res:
      print(res, line)
  except Exception as ex:
    print('error', ex, line)
    pass
