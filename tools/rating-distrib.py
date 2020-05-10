#!/usr/bin/env python3
import sys
from functools import reduce 

thresh = int(sys.argv[1]) if len(sys.argv) > 1 else 5
width = 70
longestLabel = 0
labelMap = {}
fracList = []
rateList = ['__rating_5', '__rating_4', '__rating_3', '__purge']

with open('.listen_done', 'r') as f:
  for line in f.readlines():
    parts = line.split(' ')
    label = parts[0].split('/')[0]
    rating = parts[1].strip()

    if rating == '__skipping':
      rating = '__rating_3'

    if rating not in rateList:
      continue

    if not label in labelMap:
      labelMap[label] = {}

    labelMap[label][rating] = (labelMap[label].get(rating) or 0) + 1

for label in labelMap:
  total = reduce(lambda x, y: x + y, labelMap[label].values(), 0)
  if total > thresh:
    longestLabel = max(longestLabel, len(label))
    row = {'weight': 0, 'label': label, 'total': total}
    for k,v in labelMap[label].items():
      row[k] = v / total
    
    num = len(rateList)
    for i in rateList:
      row['weight'] += num * (row.get(i) or 0)
      num -= 1

    fracList.append(row)

labelStr = "{:%d}" % (longestLabel)
fracSort = sorted(fracList, key = lambda i: i.get('weight') or 0)
for row in fracSort:
  graph = ''
  accum = 0
  start = 9608
  for i in rateList:
    accum += row.get(i) or 0
    inst = round(accum * width) - len(graph)
    draw = '.' if i == '__purge' else chr(start)
    graph += draw * inst
    start += 3

  print(labelStr.format(row['label']), graph, row['total'])
