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
		python countfunc.py testa.txt testb.txt > "$(echo $name | sed 's/ftracea/ftrace/g')"
		cat $name | grep jbd2 | awk '{print $4}' > testa.txt
		cat $name2 | grep jbd2 | awk '{print $4}' > testb.txt
		python countfunc.py testa.txt testb.txt > "$(echo $name | sed 's/ftracea/jbd2/g')"
	fi
	#else skip
done



