#!/bin/bash

# arg1: resultfilename
extentcount=0
filecount=0
for i in /home/jeongho/mnt/*; do
	level=$(cat $1 | grep -B1 "$i CREATE" | grep "current level: " | awk '{print $3}')
	if [[ $level == "" ]]; then
		continue
	fi
	filecount[level]=$((${filecount[level]}+1))
	extentcount[level]=$((${extentcount[level]}+$(filefrag $i | awk '{print $2}')))
done
for asdf in $(seq 0 10); do
	if [[ ${filecount[asdf]} != "" ]] && [[ ${filecount[asdf]} != 0 ]]; then
		echo "level $asdf fragmentation: $((${extentcount[asdf]}*100/${filecount[asdf]}))"
	fi
done