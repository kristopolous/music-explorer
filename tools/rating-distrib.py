#!/usr/bin/env python3
import sys
from functools import reduce 

thresh = 5
if len(sys.argv) > 1:
  thresh = int(sys.argv[1])

labelMap = {}
fracList = []
with open('.listen_done', 'r') as f:
  stuff = f.readlines()
  for line in stuff:
    parts = line.split(' ')
    label = parts[0].split('/')[0]
    rating = parts[1].strip()
    if rating in ['__rating_2', '__purge']: 
      rating = '__purge'

    if rating == '__skipping':
      rating = '__rating_3'

    if rating not in ['__rating_5', '__rating_4', '__rating_3', '__purge']:
      continue

    if not label in labelMap:
      labelMap[label] = {}

    if not rating in labelMap[label]:
      labelMap[label][rating] = 0

    labelMap[label][rating] += 1

# reduce to percentage and keep track of total
longestLabel = 0
for label in labelMap:
  total = reduce(lambda x,y: x + y, labelMap[label].values(), 0)
  if total > thresh:
    longestLabel = max(longestLabel, len(label))
    row = {'label': label, 'total': total}
    for k,v in labelMap[label].items():
      row[k] = v / total
    fracList.append(row)

width = 70
fracSort = sorted(fracList, key = lambda i: i.get('__rating_5') or 0)

labelStr = "{:%d}" % (longestLabel)
for row in fracSort:
  graph = ''
  accum = 0
  start = 9608
  for i in ['__rating_5', '__rating_4', '__rating_3', '__purge']:
    accum += row.get(i) or 0
    inst = round(accum * width) - len(graph)
    if i == '__purge':
      draw = '.'
    else:
      draw = chr(start)

    graph += draw * inst
    start += 3


  print(labelStr.format(row['label']), graph, row['total'])
