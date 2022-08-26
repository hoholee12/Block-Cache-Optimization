#!/bin/bash

mkdir results 2>/dev/null

function init(){
echo fillbackup_"$1"_"$2"
if [[ ! -d /home/jeongho/mntbackup2/fillbackup_"$1"_"$2" ]]; then
	mkdir /home/jeongho/mntbackup2/fillbackup_"$1"_"$2"
	./sata_ext4.sh
	./fill.sh $((7255012*4)) "$1" "$2"
	mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup2/fillbackup_"$1"_"$2"
fi
}


name="sata"
devicename="sdb"

for x in 4 12 36 108; do
	dataset=$((7255012*4))
	
	init $x yes
	echo $x l0 sst files totalling $(($x*64))MB
	./sata_ext4.sh
	cp /home/jeongho/mntbackup2/fillbackup_"$x"_yes/* /home/jeongho/mnt/
	./run_bench_bigcomp.sh $dataset $x yes seekrandom
	
done

exit

for x in 4 12 36 108; do
	dataset=$((7255012*4))
	
	init $x yes
	echo $x l0 sst files totalling $(($x*64))MB
	./sata_ext4.sh
	cp /home/jeongho/mntbackup2/fillbackup_"$x"_yes/* /home/jeongho/mnt/
	./run_bench_bigcomp.sh $dataset $x yes readseq
	
done

for x in 4 12 36 108; do
	dataset=$((7255012*4))
	
	init $x yes
	echo $x l0 sst files totalling $(($x*64))MB
	./sata_ext4.sh
	cp /home/jeongho/mntbackup2/fillbackup_"$x"_yes/* /home/jeongho/mnt/
	./run_bench_bigcomp.sh $dataset $x yes readrandom
	
done







#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)

