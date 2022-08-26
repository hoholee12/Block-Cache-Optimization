#!/bin/bash

echo fillrandom
echo dataset $1

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

mkdir /home/jeongho/mnt/fill
#generate l0
sudo time ./db_bench \
 -benchmarks="fillrandom" \
 -num=$1 \
 -threads=1 \
 -max_background_jobs=8 \
 -db=/home/jeongho/mnt/fill \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \

echo after run...
df -T | grep mnt
