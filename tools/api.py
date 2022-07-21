#!/usr/bin/env python3
import discogs_client
import secrets
import redis
import json
import sys
import operator
import re

def cachie(self):
  import requests_cache
  requests_cache.install_cache()

discogs_client.fetchers.Fetcher.__init__ = cachie

labelMap = {}
artistMap = {}

d = discogs_client.Client('ExampleApplication/0.1', user_token=secrets.USER_TOKEN)
r = redis.Redis(host='localhost', port=6379, db=0)

res = d.search(sys.argv[1], type='release')

for i in res:
  if type(i) is not discogs_client.models.Release:
    continue

  print("{}".format(i.title))
  for a in [*i.artists, *i.credits]:
    print("{:5}{}".format('', a.name))
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

      print("{:10}{}".format('', rel.title))
      lname = rel.data.get('label')
      label = r.get('label:{}'.format(lname))

      if label:
        urls = json.loads(label)
        if lname not in labelMap:
          labelMap[lname] = {'count':0, 'urls': urls}

        labelMap[lname]['count'] += 1

      else:
        for label in rel.labels:
          print("{:15}{}".format('', label.name))
          if label.name not in labelMap:
            labelMap[label.name] = {'count': 0, 'urls': label.urls}
          labelMap[label.name]['count'] += 1
          r.set('label:{}'.format(lname), json.dumps(label.urls))

ttl = []
for name, label in labelMap.items():
  urlList = [re.sub('^.*?//([^/]*).*',r'\1',x) for x in label.get('urls') or []]
  for url in urlList:
    if 'bandcamp' in url:
      ttl.append([label.get('count'), url, name])

ttl.sort(key=operator.itemgetter(0))

print("labels")
for row in ttl:
  print("{:3} {:80} {} ".format(*row))

print("\nartists")
for k,v in artistMap.items():
  print("{:3} {}".format(v, k))
