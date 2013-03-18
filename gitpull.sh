#!/bin/bash
# check for github updates, master branch
source ~/.rvm/scripts/rvm
cd ~/code/aktive-hyller
echo "# aktive-hyller update:" >> ~/code/aktive-hyller/logs/update.log 2>&1 
git stash && git pull >> ~/code/aktive-hyller/logs/update.log 2>&1
rake configure >> ~/code/aktive-hyller/logs/update.log 2>&1
echo "# rfidgeek update:" >> ~/code/aktive-hyller/logs/update.log 2>&1 
cd ~/code/rfidgeek
git stash && git pull >> ~/code/aktive-hyller/logs/update.log 2>&1 
