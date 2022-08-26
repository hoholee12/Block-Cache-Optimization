#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep smartctl_begin); do
	name=$foldername/$i
	name2=$(echo $name | sed 's/smartctl_begin/smartctl_end/g')
	val=$(cat $name | grep Wear_Leveling_Count | awk '{print $10}')
	val2=$(cat $name2 | grep Wear_Leveling_Count | awk '{print $10}')
	echo -n "$(echo $i | sed 's/_begin//g') "
	result=$(($val2-$val))
	echo $result GCed
done



