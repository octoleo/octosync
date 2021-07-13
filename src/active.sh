#!/bin/bash

# must keep the repo active or all actions will stop running after 60 days
# use UTC+00:00 time also called zulu
TODAY=$(TZ=":ZULU" date '+%A %d-%B, %Y')

echo "${TODAY}" > .active

git add .
git commit -am"active on ${TODAY}"
git push

exit 0