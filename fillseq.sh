#!/bin/bash

echo fillseq
echo dataset $((9039*$1))

if [[ $2 == "nocompact" ]]; then
 hello="-level0_slowdown_writes_trigger=1000
 -level0_stop_writes_trigger=1000
 -level0_file_num_compaction_trigger=1000
 -max_bytes_for_level_base=10485760000"
fi

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

mkdir results
#generate l0
sudo time ./db_bench \
 -benchmarks="fillseq,stats" \
 -num=$((9039*$1)) \
 -threads=1 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt/ \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 $hello \
 &> results/fillseq.txt \

# -db_write_buffer_size=$((1024*1024*13)) \

echo after run...
df -T | grep mnt

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
