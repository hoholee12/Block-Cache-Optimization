#!/bin/bash

echo uniform workload
echo dataset $1

#run
sudo time ./db_bench_"$3" \
 -benchmarks="updaterandom" \
 -num=$1 \
 -threads=1 \
 -max_background_jobs=8 \
 -subcompactions=4 \
 -histogram \
 -statistics \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 &> results/results_"$4"_"$5"g.txt \
 &
 
 ./memcheck.sh $! "$4" "$5"
 
echo after run...
df -T | grep mnt
