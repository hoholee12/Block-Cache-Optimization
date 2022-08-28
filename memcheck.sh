#!/bin/bash

maxmemsize=0

pname=cache_bench

while true; do
	sleep 1
	exist=$(pgrep $pname | head -1)
	if [[ $exist == "" ]]; then
		echo maxmemsize $maxmemsize
		exit;
	fi
	memsize=$(top -n1 | grep $pname | tail -1 | awk '{print $6}')
	if [[ $memsize -gt $maxmemsize ]]; then
		maxmemsize=$memsize
	fi

done
