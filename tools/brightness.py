#!/usr/bin/python3
#sort -n brightout.list| awk ' { print $2 } ' | xargs -n 1 identify -format "%w%h %d\/%f\n" | grep "12001200" | awk ' { print $2 } '

from PIL import Image, ImageStat
import sys, math, sys
import colorsys

width = int(sys.argv[1])

ttl = 0
bucket = [set() for i in range(width)]

def bucket_check(ix, s):
  global bucket,ttl
  if len(bucket[ix]) >= width:
    return -1
  if s in bucket[ix]:
    return 0

  bucket[ix].add(s)
  ttl += 1
  return 1



def brightness( im_file ):
  im = Image.open(im_file)
  stat = ImageStat.Stat(im)
  r,g,b = stat.mean

  # brightness is [0..255]
  brightness = math.sqrt(0.241*(r**2) + 0.691*(g**2) + 0.068*(b**2))
  ix = round(brightness / (256/(width - 1)))
  s,h,v = colorsys.rgb_to_hsv(r,g,b)

  added = bucket_check(ix, s)
  if added == -1:
    if ix > 0:
      added = bucket_check(ix-1, s)
      if added == 1:
        ix -= 1
    if ix < width and added == -1:
      added = bucket_check(ix+1, s)
      if added == 1:
        ix += 1
  
  if added == 1:
    return "{} {}".format(ix, s)

  return None
 

for line in sys.stdin:
  if ttl >= width * width:
    sys.exit(0)

  line = line.rstrip()

  try:
    res = brightness(line)
    if res:
      print(res, line)
  except Exception as ex:
    print('error', ex, line)
    pass
