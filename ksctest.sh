#!/bin/bash

mntlocation=/home/jeongho/mnt/
baklocation=/home/jeongho/mntbackup2/

runbench(){
    echo dataset $((9039*$1))
    dataset=$((9039*$1))

    echo "$2"_on_"$(($1/1024))GB"_bit"$3"_per"$((1024/$4))"
    
    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

    if [[ $2 == "seekrandom" ]]; then
        dataset=$(($dataset/50))
    fi

    sudo time ./db_bench \
    -benchmarks="fillrandom" \
    -num=$dataset \
    -threads=1 \
    -histogram \
    -statistics \
    -db=$mntlocation \
    -use_direct_io_for_flush_and_compaction=false \
    -use_direct_reads=false \
    -write_buffer_size=$(((1024/$4)*1024*1024)) \
    -target_file_size_base=$(((1024/$4)*1024*1024)) \
    -max_bytes_for_level_base=10485760000 \
    -bloom_bits=0 \
    &> results/"$2"_on_"$(($1/1024))GB"_bit"$3"_per"$((1024/$4))"_fill.txt \

    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

    #run
    sudo time ./db_bench \
    -benchmarks="$2,stats" \
    -num=$dataset \
    -threads=8 \
    -histogram \
    -statistics \
    -use_existing_db=true \
    -db=$mntlocation \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=$((1024*1024*1024*8)) \
    -bloom_bits=0 \
    -level0_slowdown_writes_trigger=1000 \
    -level0_stop_writes_trigger=1000 \
    -level0_file_num_compaction_trigger=1000 \
    -max_bytes_for_level_base=10485760000 \
    -cbhtturnoff=0 \
    -table_cache_numshardbits=$3 \
    &> results/"$2"_on_"$(($1/1024))GB"_bit"$3"_per"$((1024/$4))".txt \
    
    echo after run...
    df -T | grep mnt

    #-bloom_bits=10 \
    #    -level0_slowdown_writes_trigger=1000 \
    #-level0_stop_writes_trigger=1000 \
    #-level0_file_num_compaction_trigger=1000 \
    #-max_bytes_for_level_base=10485760000 \
}


runbench 1024 readrandom 1 1
runbench 1024 readrandom 1 2
runbench 1024 readrandom 1 4
runbench 1024 readrandom 1 8
runbench 1024 readrandom 1 16

runbench 1024 readrandom 4 1
runbench 1024 readrandom 4 2
runbench 1024 readrandom 4 4
runbench 1024 readrandom 4 8
runbench 1024 readrandom 4 16

runbench 1024 readrandom 16 1
runbench 1024 readrandom 16 2
runbench 1024 readrandom 16 4
runbench 1024 readrandom 16 8
runbench 1024 readrandom 16 16