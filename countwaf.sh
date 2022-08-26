#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep iostat_begin); do
	name=$foldername/$i
	name2=$(echo $name | sed 's/iostat_begin/iostat_end/g')
	val=$(cat $name | awk '{print $6}')
	val2=$(cat $name2 | awk '{print $6}')
	echo -n "$(echo $i | sed 's/_begin//g') "
	result=$(($(($val2-$val))/1000000))
	percent=$(($result*100/32))
	echo $result GB, $percent %
done



