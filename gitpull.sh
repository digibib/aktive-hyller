#!/bin/bash
# check for github updates, master branch
source ~/.rvm/scripts/rvm
cd ~/code/aktive-hyller
echo "# aktive-hyller update:\n" >> logs/update.log 2>&1 
git stash && git pull >> logs/update.log 2>&1
rake configure >> logs/update.log 2>&1
echo "# rfidgeek update:\n" >> logs/update.log 2>&1 
cd ~/code/rfidgeek
git stash && git pull >> logs/update.log 2>&1 
