#!/bin/bash

countme()
{
    x=0
    for i in $(cat $1 | awk '{print $6}' | sed 's/\.[^\.]*$//' | grep -x -E '[0-9]+'); do
        x=$((x+i))
    done
    #for i in $(cat $filename | awk '{print $12}' | sed 's/\.[^\.]*$//' | grep -x -E '[0-9]+'); do
        #x=$((x+i))
    #done

    echo $x
}


for i in $(ls results_cache | grep lockstat); do
    echo -n "$i "
    countme results_cache/$i
done
