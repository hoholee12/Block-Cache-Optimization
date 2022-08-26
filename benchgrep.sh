#!/bin/bash

if [[ $1 == "" ]]; then
	echo gimme something to grep
	exit
fi


for i in $(ls | grep thread); do
	mystr=$(cat $i | grep -i "$1" | awk '{print $1,$2}' | grep -v "}")
	if [[ $mystr != "" ]]; then
		echo "$i:"
		echo "$mystr"
	fi
done
