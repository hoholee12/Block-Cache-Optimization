#!/bin/bash

echo uniform workload
echo dataset $1
dataset=$1

seek_next=0
if [[ $4 == "seekrandom" ]]; then
	seek_next=50
	dataset=$(($dataset/50))
fi

yes=4
if [[ $3 == "yes" ]]; then
	yes=1000
fi

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

#run
sudo time ./db_bench_l1 \
 -benchmarks="$4,stats" \
 -seek_nexts=$seek_next \
 -num=$dataset \
 -threads=8 \
 -histogram \
 -statistics \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 -level0_slowdown_writes_trigger=1000 \
 -level0_stop_writes_trigger=1000 \
 -level0_file_num_compaction_trigger=$yes \
 -max_bytes_for_level_base=10485760000 \
 &> results/"$4"_"$2"_"$3".txt \
 
echo after run...
df -T | grep mnt
