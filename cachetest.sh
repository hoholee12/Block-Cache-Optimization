#!/bin/bash

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

ops=$(($1*1024))


# dont throttle
#i7-6700 base speed is 3.4ghz
#echo off | sudo tee /sys/devices/system/cpu/smt/control
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
echo 100 | sudo tee /sys/devices/system/cpu/intel_pstate/min_perf_pct

mkdir results_cache 2>/dev/null


i=4
shardbit=4
threads=8
constant=0.25


for percent in 80; do
    ./cache_bench --cbhtbitlength=6 --nlimit=1000 --cbhtturnoff=50 --dcaflush=0 --enableshardfix=false --skewed=true --zipf_const=$constant --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=$percent --insert_percent=$((100-$percent)) --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) #> results_cache/resultpercentenabled$percent.txt
done

exit


paramnoskip="--nlimit=20000 --cbhtturnoff=100 --dcaflush=50 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"
paramnoskipnflush="--nlimit=20000 --cbhtturnoff=100 --dcaflush=0 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"
param="--nlimit=1000 --cbhtbitlength=10 --cbhtturnoff=100 --dcaflush=0 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"
paramnoflush="--nlimit=20000 --cbhtturnoff=50 --dcaflush=0 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"
paramnodca="--nlimit=20000 --cbhtturnoff=0 --dcaflush=0 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=$threads --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"

./cache_bench $param #> results_cache/csv.txt
exit


./cache_bench $paramnoskipnflush > results_cache/csv_noskipnflush.txt
./cache_bench $paramnoskip > results_cache/csv_noskip.txt
./cache_bench $paramnoflush > results_cache/csv_noflush.txt
./cache_bench $paramnodca > results_cache/csv_nodca.txt
./cache_bench $param > results_cache/csv.txt

exit





#off
for percent in 100 90 80 70 60 50; do
    ./cache_bench --nlimit=20000 --cbhtturnoff=0 --enableshardfix=false --skewed=true --zipf_const=0.25 --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=32 --lookup_percent=$percent --insert_percent=$((100-$percent)) --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/resultpercentoff$percent.txt
done

exit


#20+ is hard limited and leads to segfault



exit


paramskip67flush33="--nlimit=20000 --cbhtturnoff=50 --dcaflush=25 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=32 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"
paramskip33flush67="--nlimit=20000 --cbhtturnoff=75 --dcaflush=50 --enableshardfix=false --skewed=true --zipf_const=$constant --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=32 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/32))"

./cache_bench $paramskip67flush33 > results_cache/csv_skip67flush33.txt
./cache_bench $paramskip33flush67 > results_cache/csv_skip33flush67.txt


exit









exit

i=4
#20+ is hard limited and leads to segfault

#valgrind --tool=helgrind ./cache_bench --skewed=true --skew=500 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/csv.txt
./cache_bench --nlimit=1000 --cbhtturnoff=20 --enableshardfix=false --skewed=true --zipf_const=0.25 --dynaswitch=false --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/csv.txt

exit



i=4
for const in 0.25 0.5 0.75 1.0; do
    ./cache_bench --enableshardfix=false --skewed=true --resident_ratio=1 --dynaswitch=true --zipf_const=$const --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/resultsdyna$const.txt
done

exit











for const in 0 0.25 0.5 0.75 1.0; do
for i in 0 1 2 3 4; do
    ./cache_bench --skewed=true --zipf_const=$const --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/result"$const"_$((2**$shardbit)).txt
done
done

exit








for i in 0 1 2 3 4; do
    ./cache_bench --skewed=false --zipf_const=0.0 --resident_ratio=1 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$shardbit --ops_per_thread=$(($ops/8)) > results_cache/result$((2**$shardbit)).txt
done

exit








