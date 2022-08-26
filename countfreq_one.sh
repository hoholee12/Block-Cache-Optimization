#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep ftrace | grep -v count); do
	if [[ $(echo $i | grep ftracea) ]]; then
		echo $i
		name=$foldername/$i
	elif [[ $(echo $i | grep ftraceb) ]]; then
		echo $i
		name2=$foldername/$i
		cat $name | awk '{print $4}' > testa.txt
		cat $name2 | awk '{print $4}' > testb.txt
		python countfunc_one.py testa.txt > "$(echo $name | sed 's/ftracea/ftracea_count/g')"
		python countfunc_one.py testb.txt > "$(echo $name2 | sed 's/ftraceb/ftraceb_count/g')"
	fi
	#else skip
done



