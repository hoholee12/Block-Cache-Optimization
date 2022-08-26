#!/bin/bash

# $1 be the folder location for checking which files have gone by

loc=$1

if [[ $1 == "" ]]; then
	loc=/home/jeongho/mnt
fi

inotifywait -m $loc -e create -e delete | while read dir action file; do echo $dir$file $action; done
