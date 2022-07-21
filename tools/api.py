#!/usr/bin/env python3

import discogs_client
import secrets
import pdb
import time
import redis
import json

d = discogs_client.Client('ExampleApplication/0.1', user_token=secrets.USER_TOKEN)

res = d.search('technocracy assassins', type='release')
print(discogs_client.utils.get_backoff_duration(1))

labelMap = {}
artistMap = {}
labelSet = set()

r = redis.Redis(host='localhost', port=6379, db=0)
start = time.time()
def clock():
  global start
  delta = time.time() - start
  start = time.time()
  return ''

for i in res:
  if type(i) is not discogs_client.models.Release:
    continue

  print("{:20} {:30}".format(clock(), i.title))
  for a in [*i.artists, *i.credits]:
    print("{:20} {:30} -> {:30}".format(clock(), i.title, a.name))
    if a.id in artistMap:
      continue

    artistMap[a.id] = a.name

    relList = a.releases
    for rel in a.releases:
      if type(rel) is discogs_client.models.Master:
        continue

      print("{:20} {:30} -> {:30} -> {:30}".format(clock(), i.title, a.name, rel.title))
      if rel.data.get('label') in labelSet: 
        continue


      lname = rel.data.get('label')
      labelSet.add(lname)

      label = r.get('label:{}'.format(lname))
      if label:
        urls = json.loads(label)
        if lname not in labelMap:
          labelMap[lname] = {'count':0,'urls': urls,'name': lname}
        else:
          labelMap[lname]['count'] += 1

      else:
        for label in rel.labels:
          print("{:20} {:30} -> {:30} -> {:30} -> {:30}".format(clock(), i.title, a.name, rel.title, label.name))
          if label.name not in labelMap:
            labelMap[label.name] = {'count': 0, 'name': label.name, 'urls': label.urls}
          labelMap[label.name]['count'] += 1
          r.set('label:{}'.format(lname), json.dumps(label.urls))

from pprint import pprint
for label in labelMap.values():
  for url in (label.get('urls') or []):
    if 'bandcamp' in url:
      print("{} {:80} {} ".format(label.get('count'), url, label.get('name')))

def get_discogs(path):
  """
  Given an album/release path this will return a discogs object
  """
