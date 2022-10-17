#!/bin/bash

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

ops=$(($1*1024))

mkdir results_cache 2>/dev/null


i=4
#20+ is hard limited and leads to segfault

#valgrind --tool=helgrind ./cache_bench --skewed=true --skew=500 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt
./cache_bench --cbhtturnoff=5 --enableshardfix=false --skewed=true --zipf_const=1 --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt

exit

i=4
for const in 0.25 0.5 0.75 1.0; do
    ./cache_bench --enableshardfix=false --skewed=true --resident_ratio=1 --dynaswitch=true --zipf_const=$const --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/resultsdyna$const.txt
done

exit








i=4
for percent in 100 90 80 70 60 50; do
    ./cache_bench --skewed=true --zipf_const=0.25 --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=$percent --insert_percent=$((100-$percent)) --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/resultpercentnoskew$percent.txt
done

exit



for const in 0 0.25 0.5 0.75 1.0; do
for i in 0 1 2 3 4; do
    ./cache_bench --skewed=true --zipf_const=$const --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/result"$const"_$((2**$i)).txt
done
done

exit








for i in 0 1 2 3 4; do
    ./cache_bench --skewed=false --zipf_const=0.0 --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/result$((2**$i)).txt
done

exit








