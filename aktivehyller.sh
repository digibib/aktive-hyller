#!/bin/bash
FIREFOX=/usr/bin/firefox
sleep 3
while true
  rm -rf ~/.mozilla/firefox/*.default/startupCache
  rm -rf ~/.mozilla/firefox/*.default/Cache
  firefox -private http://localhost:4567/timeout
  sleep 3s
end
