#!/bin/bash

foldername=$1
name=sst	#total, buf, sst
if [[ $2 != "" ]]; then name=$2; fi

for i in $(ls $foldername | grep "fragpercent_$name"); do
	total=$(cat $foldername/$i | grep "total files" | awk '{print $3}')
	acc=0
	for x in $(cat $foldername/$i | grep "files fragmented in" | awk '{print $4*$6}'); do
		acc=$(($acc+$x))
	done
	echo $i fragmented by $(($acc/$total)) percent
done



