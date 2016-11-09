#!/bin/bash

#egrep '^###' benchmark.log | egrep --only-matching 'Connections:.*|load average:.*' > filtered_uptime

#egrep '^### C|^tps' benchmark.log

DBNAME=postgres
DBUSER=postgres
LOGFILE=$(basename $0 .sh).log
MAXTXS=1000
MAXCONNS=100
#DBHOST=ec2-54-232-208-212.sa-east-1.compute.amazonaws.com
DBHOST=ec2-54-232-209-241.sa-east-1.compute.amazonaws.com
START=$(date +%s)

echo "### Started: $(date)" >> $LOGFILE

for i in $(seq 20 20 $MAXCONNS)
do
  vacuumdb -z -h $DBHOST -Upostgres $DBNAME
  for tx in $(seq 100 100 $MAXTXS)
  do
    echo "### Connections: $i Transactions: $tx" >> $LOGFILE
    echo "### $(date) -- $(uptime)" >> $LOGFILE
    pgbench -h $DBHOST -j10 -r -Mextended -n -c$i -t$tx -U$DBUSER $DBNAME >> $LOGFILE
  done
done

echo "### $(((`date +%s`-START)/60)) minutes" >> $LOGFILE
