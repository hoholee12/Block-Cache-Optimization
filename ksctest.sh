#!/bin/bash

mntlocation=/home/jeongho/mnt/
baklocation=/home/jeongho/mntbackup2/

mkdir results_ksc 2>/dev/null

runbench(){
    echo dataset $((9039*$1))
    dataset=$((9039*$1))

    echo "$2"_on_"$(($1/1024))GB"_"$3"
    
    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

    if [[ $2 == "seekrandom" ]]; then
        dataset=$(($dataset/50))
    fi

    if [[ $3 == "nocbht" ]]; then
        cbhtturnoff="-cbhtturnoff=0"
    else
        cbhtturnoff="-cbhtturnoff=20"
    fi

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
    -nlimit=2000 \
    $cbhtturnoff \
    &> results_ksc/"$2"_on_"$(($1/1024))GB"_"$3".txt \
    
    echo after run...
    df -T | grep mnt

    #-bloom_bits=10 \
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
    -threads=1 \
    -histogram \
    -statistics \
    -db=$mntlocation \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    &> results_ksc/fillrandom.txt \

    # -db_write_buffer_size=$((1024*1024*13)) \

    echo after run...
    df -T | grep mnt

    sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

}

initbench(){
    ./sata_ext4.sh
    cp $baklocation/ycsbfilldb/* $mntlocation/
}

if [[ ! -d $baklocation/ycsbfilldb ]]; then
    ./sata_ext4.sh
    fillbench 102400
    mkdir $baklocation/ycsbfilldb/
    cp $mntlocation/* $baklocation/ycsbfilldb/
fi

initbench
runbench 1024 ycsbwklda nocbht

initbench
runbench 1024 ycsbwklda

