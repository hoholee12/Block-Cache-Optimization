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
	memsize=$(($(cat /proc/$exist/stat | awk '{print $24}')*4096)) 2>/dev/null
	if [[ $memsize -gt $maxmemsize ]]; then
		maxmemsize=$memsize
	fi

done
