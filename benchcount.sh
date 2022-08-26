#!/bin/bash

if [[ $1 == "" ]]; then
	echo what to find?
	exit
fi

for i in $(ls | grep thread); do echo -n "$i: "; cat $i | grep -i $1 | wc -l; done
