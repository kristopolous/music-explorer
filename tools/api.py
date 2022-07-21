#!/usr/bin/env python3
import discogs_client
import secrets
import pdb
import time
import redis
import json
import sys
import requests
import re

d = discogs_client.Client('ExampleApplication/0.1', user_token=secrets.USER_TOKEN)

labelMap = {}
artistMap = {}

r = redis.Redis(host='localhost', port=6379, db=0)

res = d.search(sys.argv[1], type='release')
for i in res:
  if type(i) is not discogs_client.models.Release:
    continue

  print("{:20} {:40}".format('', i.title))
  for a in [*i.artists, *i.credits]:
    print("{:20} {:40} -> {:30}".format('', i.title, a.name))
    try:
      if a.name in artistMap:
        artistMap[a.name] += 1
        continue

      artistMap[a.name] = 1
      relList = a.releases

    except:
      continue

    for rel in a.releases:
      if type(rel) is discogs_client.models.Master:
        continue

      print("{:20} {:40} -> {:30} -> {:30}".format('', i.title, a.name, rel.title))
      lname = rel.data.get('label')
      label = r.get('label:{}'.format(lname))
      if label:
        urls = json.loads(label)
        if lname not in labelMap:
          labelMap[lname] = {'count':0,'urls': urls,'name': lname}

        labelMap[lname]['count'] += 1

      else:
        for label in rel.labels:
          print("{:20} {:40} -> {:30} -> {:30} -> {:30}".format('', i.title, a.name, rel.title, label.name))
          if label.name not in labelMap:
            labelMap[label.name] = {'count': 0, 'name': label.name, 'urls': label.urls}
          labelMap[label.name]['count'] += 1
          r.set('label:{}'.format(lname), json.dumps(label.urls))

for label in labelMap.values():
  urlList = [re.sub('^.*?//([^/]*).*',r'\1',x) for x in label.get('urls') or []]
  for url in urlList:
    if 'bandcamp' in url:
      print("{} {:80} {} ".format(label.get('count'), url, label.get('name')))

for k,v in artistMap.items():
  print(v, k)
