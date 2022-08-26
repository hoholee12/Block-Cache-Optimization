#!/bin/bash

echo updaterandom
echo dataset $1
dataset=$1

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

smartctl -A /dev/sdb &> results/results_smartctl_begin_"$2"_"$(($dataset/9256395))"g.txt
iostat | grep sdb > results/results_iostat_begin_"$2"_"$(($dataset/9256395))"g.txt

#run
sudo time ./db_bench \
 -benchmarks="updaterandom,stats" \
 -num=$dataset \
 -histogram \
 -statistics \
 -threads=1 \
 -max_background_jobs=8 \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 &> results/results_"$2"_"$(($dataset/9256395))"g.txt \
 
smartctl -A /dev/sdb &> results/results_smartctl_end_"$2"_"$(($dataset/9256395))"g.txt
iostat | grep sdb > results/results_iostat_end_"$2"_"$(($dataset/9256395))"g.txt