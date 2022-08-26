#!/bin/bash

echo skewed workload
echo dataset $1

#run
sudo time ./db_bench_"$3" \
 -benchmarks="mixgraph" \
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
 -key_dist_a=0.002312 \
 -key_dist_b=0.3467 \
 -keyrange_num=1 \
 -value_k=0.2615 \
 -value_sigma=25.45 \
 -iter_k=2.517 \
 -iter_sigma=14.236 \
 -mix_get_ratio=0.5 \
 -mix_put_ratio=0.5 \
 -mix_seek_ratio=0.0 \
 -sine_mix_rate_interval_milliseconds=5000 \
 -sine_a=1000 \
 -sine_b=0.00000073 \
 -sine_d=450000 \
 &> results/results_mixgraph_"$4"_"$5"g.txt \

# &
#./memcheck.sh $! "$4" "$5"
 
echo after run...
df -T | grep mnt
