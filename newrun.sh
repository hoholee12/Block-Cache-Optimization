#!/bin/bash

mntlocation=/home/mj123/mnt/
baklocation=/home/mj123/mntbackup2/

runbench(){
    echo dataset $((9039*$1))
    dataset=$((9039*$1))

    echo "$2"_on_"$(($1/1024))GB"_"$3"_"$4"_"$5"_"$6"
    
    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

    if [[ $2 == "seekrandom" ]]; then
        dataset=$(($dataset/50))
    fi

    if [[ $3 == "nocbht" ]]; then
        cbhtturnoff="-cbhtturnoff=0"
    else
        cbhtturnoff="-cbhtturnoff=100"
    fi

    if [[ $4 == "nodcaprefetch" ]]; then
        dcaprefetch="-dcaprefetch=false"
        prefetchvalue=""
    else
        dcaprefetch="-dcaprefetch=true"
        prefetchvaule="-dcasizelimit=$5"
    fi

    if [[ $6 == "clockcache" ]]; then
        clockcache="-use_clock_cache=true"
    else
        clockcache="-use_clock_cache=false"
    fi

    mkdir results 2>/dev/null

    #run
    sudo time ./db_bench \
    -benchmarks="$2,stats" \
    -num=$dataset \
    -threads=16 \
    -histogram \
    -statistics \
    -use_existing_db=true \
    -seed=1000 \
    -db=$mntlocation \
    -nlimit=10000 \
    $dcaprefetch \
    $prefetchvalue \
    $clockcache \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=$((1024*1024*1024*2)) \
    $cbhtturnoff \
    $prefetchvalue \
    &> results/"$2"_on_"$(($1/1024))GB"_"$3"_"$4"_"$5"_"$6".txt \
    
    echo after run...
    df -T | grep mnt

    #-bloom_bits=10 \
    #-cache_numshardbits=4 \
    #    -level0_slowdown_writes_trigger=1000 \
    #-level0_stop_writes_trigger=1000 \
    #-level0_file_num_compaction_trigger=1000 \
    #-max_bytes_for_level_base=10485760000 \
}

fillbench(){
    echo ycsbfilldb
    echo dataset $((9039*$1))

    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

    mkdir results 2>/dev/null
    #generate l0
    sudo time ./db_bench \
    -benchmarks="ycsbfilldb" \
    -num=$((9039*$1)) \
    -threads=16 \
    -histogram \
    -statistics \
    -seed=1000 \
    -zipf_const=0.0 \
    -db=$mntlocation \
    &> results/fillrandom.txt \

    # -db_write_buffer_size=$((1024*1024*13)) \

    echo after run...
    df -T | grep mnt

    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

}

initbench(){
    ./nvme_ext4.sh
    cp $baklocation/ycsbfilldb/* $mntlocation/
}

if [[ ! -d $baklocation/ycsbfilldb ]]; then
    ./nvme_ext4.sh
    fillbench 10240
    mkdir $baklocation/ycsbfilldb/
    cp $mntlocation/* $baklocation/ycsbfilldb/
fi

# dont throttle
#i7-6700 base speed is 3.4ghz
#echo off | sudo tee /sys/devices/system/cpu/smt/control
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
echo 100 | sudo tee /sys/devices/system/cpu/intel_pstate/min_perf_pct




initbench
runbench 1024 ycsbwklda yescbht yesdcaprefetch 50


initbench
runbench 1024 ycsbwkldb yescbht yesdcaprefetch 50


initbench
runbench 1024 ycsbwkldc yescbht yesdcaprefetch 50


initbench
runbench 1024 ycsbwkldd yescbht yesdcaprefetch 50


initbench
runbench 1024 ycsbwklde yescbht yesdcaprefetch 50


initbench
runbench 1024 ycsbwkldf yescbht yesdcaprefetch 50