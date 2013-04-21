#!/bin/bash

# Generate omtaler.csv: time, uri, author, title, reviewsnum
cat logs/all.log | grep $(eval date +%Y-%m-%d) | grep "Omtalevisning" | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | awk '{ print $2, $8, $10, $11 ,$9 }' | awk -F\" '{OFS="\"";for(i=2;i<NF;i+=2)gsub(/ /,"@",$i);print}' | sed  's/\s\+/|/g' | tr @ " " | sed s/\"//g | cut -c 2- > logs/omtaler.csv

# Generate sessions.csv: start, stop, rfid, omtale, flere, relaterte
cat logs/all.log | grep $(eval date +%Y-%m-%d) | grep "Finito" | awk '{ print $8, $9, $10, $11, $12, $13 }' | sed  's/\s\+/|/g' > logs/sessions.csv

# Import csv into database
sqlite3 logs/stats.db < logs/import.sql

# Clean up
rm logs/{omtaler.csv,sessions.csv}
