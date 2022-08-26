#!/bin/bash

echo uniform workload
echo dataset $1

yes=4
if [[ $3 == "yes" ]]; then
	yes=$2
fi

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

mkdir /home/jeongho/mnt/fill
#generate l0
sudo time ./db_bench \
 -benchmarks="fillrandom,stats" \
 -num=$1 \
 -threads=8 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt/fill \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 -level0_slowdown_writes_trigger=$2 \
 -level0_stop_writes_trigger=$2 \
 -level0_file_num_compaction_trigger=$yes \
 &> results/fill_$2_$3.txt \

echo after run...
df -T | grep mnt
