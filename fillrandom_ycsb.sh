#!/bin/bash

echo ycsbfilldb
echo dataset $((9039*$1))


if [[ $2 == "bloom" ]]; then
	bloom="-bloom_bits=10"
fi

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

mkdir results
#generate l0
sudo time ./db_bench \
 -benchmarks="ycsbfilldb" \
 -num=$((9039*$1)) \
 -threads=1 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt/ \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 $bloom \
 &> results/fillrandom.txt \

# -db_write_buffer_size=$((1024*1024*13)) \

echo after run...
df -T | grep mnt

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
