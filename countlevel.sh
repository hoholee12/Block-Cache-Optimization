#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep -v 'iostat\|smartctl\|ftrace'); do
	echo $i
	echo "level 0 CREATE: $(cat $foldername/$i | grep 'current level: 0' | wc -l)"
	echo "level 1 CREATE: $(cat $foldername/$i | grep 'current level: 1' | wc -l)"
	echo "level 2 CREATE: $(cat $foldername/$i | grep 'current level: 2' | wc -l)"
	echo "level 3 CREATE: $(cat $foldername/$i | grep 'current level: 3' | wc -l)"
	echo "level 4 CREATE: $(cat $foldername/$i | grep 'current level: 4' | wc -l)"
	echo "level 5 CREATE: $(cat $foldername/$i | grep 'current level: 5' | wc -l)"
	echo "level 0 DELETE: $(cat $foldername/$i | grep 'DELETE level:0' | wc -l)"
	echo "level 1 DELETE: $(cat $foldername/$i | grep 'DELETE level:1' | wc -l)"
	echo "level 2 DELETE: $(cat $foldername/$i | grep 'DELETE level:2' | wc -l)"
	echo "level 3 DELETE: $(cat $foldername/$i | grep 'DELETE level:3' | wc -l)"
	echo "level 4 DELETE: $(cat $foldername/$i | grep 'DELETE level:4' | wc -l)"
	echo "level 5 DELETE: $(cat $foldername/$i | grep 'DELETE level:5' | wc -l)"
	echo "level buf DELETE: $(($(cat $foldername/$i | grep 'buf DELETE' | wc -l)-$(cat $foldername/$i | grep 'sst DELETE again' | wc -l)))"
	echo "level sst DELETE: $(cat $foldername/$i | grep 'sst DELETE' | wc -l)"
	echo "wal log DELETE: $(cat $foldername/$i | grep 'log DELETE' | wc -l)"

	echo
done
