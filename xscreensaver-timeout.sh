#!/bin/bash

process() {
while read input; do 
  case "$input" in
    BLANK*)     
      (echo 'GET /timeout ';sleep 1) | telnet localhost 4567 
      #[ -f aktivehyller.mp4 ] && avplay -fs -loop 0 aktivehyller.mp4 # screensaver in full screen loop
      ;;
    UNBLANK*)	echo "start something? " ;;
    LOCK*)	echo "lock .... do nothing yet" ;;
  esac
done
}

/usr/bin/xscreensaver-command -watch | process
