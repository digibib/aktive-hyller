#!/bin/bash

process() {
while read input; do 
  case "$input" in
    BLANK*)     /usr/bin/pkill firefox ;;
    UNBLANK*)	echo "start something? " ;;
    LOCK*)	echo "lock .... do nothing yet" ;;
  esac
done
}

/usr/bin/xscreensaver-command -watch | process
