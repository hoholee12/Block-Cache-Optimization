#!/bin/bash

mkdir results 2>/dev/null

freespace=4096

function freespaceme(){
echo freespace... "$freespace"
mkdir /home/jeongho/mnt/stuffing
dd if=/dev/zero of=/home/jeongho/mnt/stuffing/s0 bs=1M count=$freespace >/dev/null 2>&1
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/stuffing/s1 2>/dev/null
rm -rf /home/jeongho/mnt/stuffing/s0
}

function init(){
if [[ ! -d /home/jeongho/mntbackup/fillbackup_"$1" ]]; then
	mkdir /home/jeongho/mntbackup/fillbackup_"$1"
	./sata_f2fs.sh
	mkdir /home/jeongho/mnt/stuffing
	dd if=/dev/zero of=/home/jeongho/mnt/stuffing/s0 bs=1M count=$freespace >/dev/null 2>&1
	./fill.sh $((7255012*500)) "$1"
	mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup/fillbackup_"$1"
fi
}

# arg1: name, arg2: appending num, arg3: dataset, arg4: which level, arg5: devicename, arg6: space?, arg7: bk1(70)/bk2(100)
function testme(){
fsname=f2fs
if [[ "$(echo $1 | grep ext4)" ]]; then
	fsname=ext4
fi
if [[ "$(echo $1 | grep xfs)" ]]; then
	fsname=xfs
fi
if [[ "$(echo $7 | grep bk1)" ]]; then
	cp /home/jeongho/mntbackup2/fillbackup_"$4"/* /home/jeongho/mnt
else
	cp /home/jeongho/mntbackup/fillbackup_"$4"/* /home/jeongho/mnt
fi
if [[ "$6" == "" ]]; then
	freespaceme
fi
../blktrace_results/traceme_"$name".sh "$1"_"$2"g &
blkcheck=$!
echo begin check "$1"...
smartctl -A /dev/"$5" &> results/results_"$1"_smartctl_begin_"$2"g.txt
iostat | grep "$5" > results/results_"$1"_iostat_begin_"$2"g.txt
# 100mb ftrace before
echo begin first trace
trace-cmd record -e "$fsname" ./run_bench.sh 725501 false "$4" > /dev/null
sleep 1
trace-cmd report > results/results_"$1"_ftracea_"$2"g.txt
rm trace.dat
# main load
echo run workload
./run_bench.sh "$3" false "$4" &> results/results_"$1"_"$2"g.txt
# 100mb ftrace after
echo begin second trace
trace-cmd record -e "$fsname" ./run_bench.sh 725501 false "$4" > /dev/null
sleep 1
trace-cmd report > results/results_"$1"_ftraceb_"$2"g.txt
rm trace.dat
smartctl -A /dev/"$5" &> results/results_"$1"_smartctl_end_"$2"g.txt
iostat | grep "$5" > results/results_"$1"_iostat_end_"$2"g.txt
killall blktrace
}

#for each workloads
# $1 = num
# $2 = workload type

name="sata"
devicename="sdb"


	# with no ssr
	#echo testing nossr...
	#./"$name"_f2fs_nossr.sh
	#testme "nossr" "$x" "$dataset" "l0" "$devicename"

init "l0"
init "l1"

for x in 32; do
	dataset_size=$x
	dataset=$((7255012*$dataset_size))
	freespace=$(($x/32*4096))
	
	# with ssr
	#echo testing ssr...
	#./"$name"_f2fs.sh
	#testme "ssr" "$x" "$dataset" "l0" "$devicename"
	
	# whint fsbased
	#echo testing whint_fsbased...
	#./"$name"_f2fs_whint.sh
	#testme "ssr_whint" "$x" "$dataset" "l0" "$devicename"

	# with l1+ as cold
	#echo testing l0...
	#./"$name"_f2fs_ext.sh
	#testme "l0" "$x" "$dataset" "l0" "$devicename"

	# with l2+ as cold
	#echo testing l1...
	#./"$name"_f2fs_ext.sh
	#testme "l1" "$x" "$dataset" "l1" "$devicename"
	
	# with l1+ as warm
	#echo testing l0_warm...
	#./"$name"_f2fs_ext_warm.sh
	#testme "l0_warm" "$x" "$dataset" "l0" "$devicename"

	# with l2+ as warm
	#echo testing l1 warm...
	#./"$name"_f2fs_ext_warm.sh
	#testme "l1_warm" "$x" "$dataset" "l1" "$devicename"
	
	# ext4
	#echo testing ext4...
	#./"$name"_ext4.sh
	#testme "ext4" "$x" "$dataset" "l0" "$devicename"

	# with ssr with space
	#echo testing ssr... with space
	#./"$name"_f2fs.sh
	#testme "ssr_space" "$x" "$dataset" "l0" "$devicename" "space"

	# with l1+ as cold with space
	#echo testing l0... with space
	#./"$name"_f2fs_ext.sh
	#testme "l0_space" "$x" "$dataset" "l0" "$devicename" "space"

	# with l2+ as cold with space
	#echo testing l1... with space
	#./"$name"_f2fs_ext.sh
	#testme "l1_space" "$x" "$dataset" "l1" "$devicename" "space"
	
	# with l1+ as warm with space
	#echo testing l0_warm... with space
	#./"$name"_f2fs_ext_warm.sh
	#testme "l0_warm_space" "$x" "$dataset" "l0" "$devicename" "space"

	# with l2+ as warm with space
	#echo testing l1_warm... with space
	#./"$name"_f2fs_ext_warm.sh
	#testme "l1_warm_space" "$x" "$dataset" "l1" "$devicename" "space"

	# ext4 with space
	#echo testing ext4... with space
	#./"$name"_ext4.sh
	#testme "ext4_space" "$x" "$dataset" "l0" "$devicename" "space"
	
	# with l1+ as cold with space with reverse
	#echo testing l0... with space with reverse
	#./"$name"_f2fs_ext_reverse.sh
	#testme "l0_space_reverse" "$x" "$dataset" "l0" "$devicename" "space"

	# with l2+ as cold with space with reverse
	#echo testing l1... with space with reverse
	#./"$name"_f2fs_ext_reverse.sh
	#testme "l1_space_reverse" "$x" "$dataset" "l1" "$devicename" "space"
	
	# with l1+ as warm with space with reverse
	#echo testing l0_warm... with space with reverse
	#./"$name"_f2fs_ext_warm_reverse.sh
	#testme "l0_warm_space_reverse" "$x" "$dataset" "l0" "$devicename" "space"

	# with l2+ as warm with space with reverse
	#echo testing l1_warm... with space with reverse
	#./"$name"_f2fs_ext_warm_reverse.sh
	#testme "l1_warm_space_reverse" "$x" "$dataset" "l1" "$devicename" "space"
	
	# with l3+ as cold with space with reverse
	#echo testing l2... with space with reverse
	#./"$name"_f2fs_ext_reverse.sh
	#testme "l2_space_reverse" "$x" "$dataset" "l2" "$devicename" "space"
	
	# with l3+ as warm with space with reverse
	#echo testing l2_warm... with space with reverse
	#./"$name"_f2fs_ext_warm_reverse.sh
	#testme "l2_warm_space_reverse" "$x" "$dataset" "l2" "$devicename" "space"
	
	# all of rocksdb on hot
	#echo testing ssr_steroids... with space
	#./"$name"_f2fs_steroids.sh
	#testme "ssr_steroids" "$x" "$dataset" "l0" "$devicename" "space"
	
	# xfs with space
	#echo testing xfs... with space
	#./"$name"_xfs.sh
	#testme "xfs_space" "$x" "$dataset" "l0" "$devicename" "space"


	##real test
	
	# with ssr with space
	echo testing ssr... with space bk1
	./"$name"_f2fs.sh
	testme "ssr_space_bk1" "$x" "$dataset" "l0" "$devicename" "space" "bk1"
	
	# all of rocksdb on hot
	echo testing ssr_steroids... with space bk1
	./"$name"_f2fs_steroids.sh
	testme "ssr_steroids_bk1" "$x" "$dataset" "l0" "$devicename" "space" "bk1"
	
	# xfs with space
	echo testing xfs... with space bk1
	./"$name"_xfs.sh
	testme "xfs_space_bk1" "$x" "$dataset" "l0" "$devicename" "space" "bk1"
	
	# ext4 with space
	echo testing ext4... with space bk1
	./"$name"_ext4.sh
	testme "ext4_space_bk1" "$x" "$dataset" "l0" "$devicename" "space" "bk1"
	
	# with ssr with space
	echo testing ssr... with space bk2
	./"$name"_f2fs.sh
	testme "ssr_space_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# all of rocksdb on hot
	echo testing ssr_steroids... with space bk2
	./"$name"_f2fs_steroids.sh
	testme "ssr_steroids_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# xfs with space
	echo testing xfs... with space bk2
	./"$name"_xfs.sh
	testme "xfs_space_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# ext4 with space
	echo testing ext4... with space bk2
	./"$name"_ext4.sh
	testme "ext4_space_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"

done

#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)

