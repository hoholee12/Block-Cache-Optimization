#!/bin/bash

if [[ $1 == "init" ]]; then
	rm -rf /tmp/rocksdbtest-*
	./db_bench -benchmarks=fillrandom -write_buffer_size=1000 -target_file_size_base=1000 -num=100000
	uftrace ./db_bench -benchmarks=readrandom -write_buffer_size=1000 -target_file_size_base=1000 -num=1000 -use_existing_db=true > test.txt
elif [[ $1 == "withlinenum" ]]; then
	rm -rf thread*.c
	x=-1
	unset thread_list
	for i in $(cat test.txt | sed -n 's/.*\[\(.*[0-9]\)\].*/\1/p'); do
		if [[ ! ${thread_list[*]} =~ $i ]]; then
			x=$(($x+1))
			thread_list[$x]=$i
		fi
	done

	for j in ${thread_list[@]}; do
		cat test.txt | grep -n "$j]" | sed -n 's/\([0-9]*\):.*|\(.*\)/\/\*\1\*\/\t\t\2/p' > thread$j.c
	done
elif [[ $1 == "withoutlinenum" ]]; then
	rm -rf thread*.c
	x=-1
	unset thread_list
	for i in $(cat test.txt | sed -n 's/.*\[\(.*[0-9]\)\].*/\1/p'); do
		if [[ ! ${thread_list[*]} =~ $i ]]; then
			x=$(($x+1))
			thread_list[$x]=$i
		fi
	done

	for j in ${thread_list[@]}; do
		cat test.txt | grep "$j]" | sed 's/.*|//g' > thread$j.c
	done
fi
