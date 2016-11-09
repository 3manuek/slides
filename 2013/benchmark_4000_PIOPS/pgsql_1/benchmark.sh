#!/bin/bash

DBNAME=benchmark
DBUSER=postgres
LOGFILE=$(basename -s .sh $0).log
MAXTXS=1000
MAXCONNS=96
START=$(date +%s)

echo "### Started: $(date)" >> $LOGFILE

for i in $(seq 16 16 $MAXCONNS) 
do
  vacuumdb -z -Upostgres benchmark
  for tx in $(seq 100 100 $MAXTXS)
  do
    echo "### Connections: $i Transactions: $tx" >> $LOGFILE
    echo "### $(date) -- $(uptime)" >> $LOGFILE
    pgbench -j4 -r -Mextended -n -c$i -t$tx -U$DBUSER $DBNAME >> $LOGFILE
  done
done

echo "### $(((`date +%s`-START)/60)) minutes" >> $LOGFILE
