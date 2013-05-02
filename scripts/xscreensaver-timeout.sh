#!/bin/bash

process() {
while read input; do 
  case "$input" in
    BLANK*)    (sleep 1 ; echo 'GET /timeout ') | telnet localhost 4567 
                /usr/bin/firefox --display=:0.0 -remote "openurl(localhost:4567)" ;;
    UNBLANK*)	  echo "start something? " ;;
    LOCK*)	    echo "lock .... do nothing yet" ;;
  esac
done
}

/usr/bin/xscreensaver-command -d :0.0 -watch | process
