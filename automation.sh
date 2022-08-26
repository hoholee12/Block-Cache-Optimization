#!/bin/bash

#./sata_ext4.sh
#./fillseq.sh 100
#./run_bench_bigcomp.sh 100 fillseq readseq
#./run_bench_bigcomp.sh 100 fillseq readrandom
#./run_bench_bigcomp.sh 100 fillseq seekrandom

./sata_ext4.sh
./fillrandom.sh 100 yescompact bloom
./run_bench_bigcomp.sh 100 100MB_bloom_shard_1 readrandom bloom 1

./sata_ext4.sh
./fillrandom.sh 100 yescompact bloom
./run_bench_bigcomp.sh 100 100MB_bloom_shard_2 readrandom bloom 2

./sata_ext4.sh
./fillrandom.sh 100 yescompact bloom
./run_bench_bigcomp.sh 100 100MB_bloom_shard_4 readrandom bloom 4

./sata_ext4.sh
./fillrandom.sh 100 yescompact bloom
./run_bench_bigcomp.sh 100 100MB_bloom_shard_8 readrandom bloom 8
#./sata_ext4.sh
#./fillrandom.sh 1000 yescompact bloom
#./run_bench_bigcomp.sh 100 1GB_bloom readrandom bloom
#./sata_ext4.sh
#./fillrandom.sh 10000 yescompact bloom
#./run_bench_bigcomp.sh 100 10GB_bloom readrandom bloom

#./sata_ext4.sh
#./fillrandom.sh 100
#./run_bench_bigcomp.sh 100 100MB readrandom
#./sata_ext4.sh
#./fillrandom.sh 1000
#./run_bench_bigcomp.sh 100 1GB readrandom
#./sata_ext4.sh
#./fillrandom.sh 10000
#./run_bench_bigcomp.sh 100 10GB readrandom

#./sata_ext4.sh
#cp ~/mntbackup2/fillrandom100gb/* ~/mnt/
#./run_bench_bigcomp.sh 100 100GB readrandom

./sata_ext4.sh
cp ~/mntbackup2/fillrandom100gb_bloom/* ~/mnt/
./run_bench_bigcomp.sh 100 100GB_bloom_shard_1 readrandom bloom 1

./sata_ext4.sh
cp ~/mntbackup2/fillrandom100gb_bloom/* ~/mnt/
./run_bench_bigcomp.sh 100 100GB_bloom_shard_2 readrandom bloom 2

./sata_ext4.sh
cp ~/mntbackup2/fillrandom100gb_bloom/* ~/mnt/
./run_bench_bigcomp.sh 100 100GB_bloom_shard_4 readrandom bloom 4

./sata_ext4.sh
cp ~/mntbackup2/fillrandom100gb_bloom/* ~/mnt/
./run_bench_bigcomp.sh 100 100GB_bloom_shard_8 readrandom bloom 8

#./run_bench_bigcomp.sh 100 fillrandom readrandom
#./run_bench_bigcomp.sh 100 fillrandom seekrandom

