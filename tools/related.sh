#!/bin/bash

term="$(grep -hPo '(?<=og:title. content=")([^"]*)' $1/page.html | sed -E s'/, by//g')"
./api.py "$term"
