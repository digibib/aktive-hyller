#!/bin/bash
FIREFOX=/usr/bin/firefox
sleep 3
while true
do
  rm -rf ~/.mozilla/firefox/*.default/startupCache
  rm -rf ~/.mozilla/firefox/*.default/Cache
  firefox http://localhost:4567/timeout
  sleep 3s
done
