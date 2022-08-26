#!/bin/bash

mkdir results_age 2>/dev/null

function freespaceme(){
echo "generate full size"
mkdir /home/jeongho/mnt/fill/
fallocate -l $(($(df -h | grep sdb | awk '{print $2}' | sed 's/G//g')/3))G /home/jeongho/mnt/fill/fillme.buf 2>/dev/null
fallocate -l $(($(df -h | grep sdb | awk '{print $2}' | sed 's/G//g')/3))G /home/jeongho/mnt/fill/fillme.warm 2>/dev/null
fallocate -l $(($(df -h | grep sdb | awk '{print $2}' | sed 's/G//g')/3))G /home/jeongho/mnt/fill/fillme.sst 2>/dev/null
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/fill/fillme.buf 2>/dev/null
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/fill/fillme.warm 2>/dev/null
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/fill/fillme.sst 2>/dev/null

echo "punch hole"
./punch /home/jeongho/mnt/fill/fillme.buf
./punch /home/jeongho/mnt/fill/fillme.warm
./punch /home/jeongho/mnt/fill/fillme.sst
}

function freespacemore(){
echo "fill alittle more"
mkdir /home/jeongho/mnt/fill/
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/fill/fillme2.warm 2>/dev/null
./punch /home/jeongho/mnt/fill/fillme2.warm

}

#arg1: protname(sata, nvme), arg2: drivename(sdb1, nvme0n1p1)
function init(){
	protname=$1
	drivename=$2
	if [[ -d /home/jeongho/mntbackup/fillbackup_"$protname" ]]; then return; fi
	./"$protname"_f2fs_custom.sh
	freespace=$(($(df -h | grep "$drivename" | awk '{print $2}' | sed 's/G//g')*8/10+8))
	fallocate -l "$freespace"G /home/jeongho/mnt/initfill.buf 2>/dev/null
	./fill.sh $((7255012*1000)) "l1"
	mkdir /home/jeongho/mntbackup/fillbackup_"$protname"
	mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup/fillbackup_"$protname"/
}

function blktraceme(){
	if [[ -d ../mntbackup2/blktraces_"$1"g ]]; then
		rm -rf ../mntbackup2/blktraces_"$1"g
	fi

	#delete trace after analysis for space
	mkdir ../mntbackup2/blktraces_"$1"g
	mv *blktrace* ../mntbackup2/blktraces_"$1"g/
	../blktrace_results/printme.sh ../mntbackup2/blktraces_"$1"g
}

# arg1: resultfilename
function fragperlevel(){
	extentcount=0
	filecount=0
	for i in /home/jeongho/mnt/*; do
		level=$(cat $1 | grep -B1 "$i CREATE" | grep "current level: " | awk '{print $3}')
		if [[ $level == "" ]]; then
			continue
		fi
		filecount[level]=$((${filecount[level]}+1))
		extentcount[level]=$((${extentcount[level]}+$(filefrag $i | awk '{print $2}')))
	done
	for asdf in $(seq 0 10); do
		if [[ ${filecount[asdf]} != "" ]]; then
			echo "level $asdf fragmentation: $((${extentcount[asdf]}/${filecount[asdf]}))"
		fi
	done
}

#fillrandomtest
# arg1: name, arg2: appending num, arg3: dataset, arg4: which level, arg5: devicename
function pretestme(){
	fsname=f2fs
	if [[ "$(echo $1 | grep ext4)" ]]; then
		fsname=ext4
	fi
	if [[ "$(echo $1 | grep xfs)" ]]; then
		fsname=xfs
	fi
	
	# free memory before test
	sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

	#../blktrace_results/traceme_"$name".sh "$1"_"$2"g &
	#blkcheck=$!
	echo begin check "$1"...
	smartctl -A /dev/"$5" &> results_age/results_age_"$1"_smartctl_begin_"$2"g.txt
	iostat | grep "$5" > results_age/results_age_"$1"_iostat_begin_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_age_"$1"_f2fsstat_begin_"$2"g.txt
	fi
	# 100mb ftrace before
	#echo begin first trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_age_"$1"_ftracea_"$2"g.txt
	#rm trace.dat
	# main load
	#./run_bench_age.sh 725501 false "$4" > /dev/null
	echo run fillrandom "$2"g
	#./run_bench_age.sh "$3" false "$4" "$1" "$2"
	myoutput=results_age/results_age_"$1"_"$2"g.txt
	./run_bench_age.sh "$3" false "l1" "$1" "$2" init &> $myoutput
	# 100mb ftrace after
	#echo begin second trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_age_"$1"_ftraceb_"$2"g.txt
	#rm trace.dat
	smartctl -A /dev/"$5" &> results_age/results_age_"$1"_smartctl_end_"$2"g.txt
	iostat | grep "$5" > results_age/results_age_"$1"_iostat_end_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_age_"$1"_f2fsstat_end_"$2"g.txt
	fi
	#killall blktrace

	# check fragmentation
	fragperlevel $myoutput > results_age/results_age_"$1"_fragpercent_level_"$2"g.txt
	filefrag /home/jeongho/mnt/* | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_age_"$1"_fragpercent_total_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep sst | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_age_"$1"_fragpercent_sst_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep buf | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_age_"$1"_fragpercent_buf_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep log | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_age_"$1"_fragpercent_log_"$2"g.txt
	#intact=$(($(filefrag /home/jeongho/mnt/* | grep "1 extent\|0 extent" | wc -l)*100))
	#total=$(filefrag /home/jeongho/mnt/* | wc -l)
	#fragpercentage=$((100-$(($intact/$total))))
	#echo $fragpercentage > results_age/results_age_"$1"_fragpercent_"$2"g.txt
}

# arg1: name, arg2: appending num, arg3: dataset, arg4: which level, arg5: devicename
function testme(){
	fsname=f2fs
	if [[ "$(echo $1 | grep ext4)" ]]; then
		fsname=ext4
	fi
	if [[ "$(echo $1 | grep xfs)" ]]; then
		fsname=xfs
	fi
	
	cp /home/jeongho/mntbackup2/fillbackup_"$4"/* /home/jeongho/mnt
	freespacemore
	
	#openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/fill/fillme3.warm 2>/dev/null
	#./punch /home/jeongho/mnt/fill/fillme3.warm
		
	# free memory before test
	sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

	#../blktrace_results/traceme_"$name".sh "$1"_"$2"g &
	#blkcheck=$!
	echo begin check "$1"...
	smartctl -A /dev/"$5" &> results_age/results_"$1"_smartctl_begin_"$2"g.txt
	iostat | grep "$5" > results_age/results_"$1"_iostat_begin_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_"$1"_f2fsstat_begin_"$2"g.txt
	fi
	# 100mb ftrace before
	#echo begin first trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_"$1"_ftracea_"$2"g.txt
	#rm trace.dat
	# main load
	#./run_bench_age.sh 725501 false "$4" > /dev/null
	echo run updaterandom "$2"g
	#./run_bench_age.sh "$3" false "$4" "$1" "$2"
	myoutput=results_age/results_"$1"_"$2"g.txt
	./run_bench_age.sh "$3" false "l1" "$1" "$2" &> $myoutput
	# 100mb ftrace after
	#echo begin second trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_"$1"_ftraceb_"$2"g.txt
	#rm trace.dat
	smartctl -A /dev/"$5" &> results_age/results_"$1"_smartctl_end_"$2"g.txt
	iostat | grep "$5" > results_age/results_"$1"_iostat_end_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_"$1"_f2fsstat_end_"$2"g.txt
	fi
	#killall blktrace

	# check fragmentation
	fragperlevel $myoutput > results_age/results_age_"$1"_fragpercent_level_"$2"g.txt
	filefrag /home/jeongho/mnt/* | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_total_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep sst | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_sst_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep buf | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_buf_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep log | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_log_"$2"g.txt
	#intact=$(($(filefrag /home/jeongho/mnt/* | grep "1 extent\|0 extent" | wc -l)*100))
	#total=$(filefrag /home/jeongho/mnt/* | wc -l)
	#fragpercentage=$((100-$(($intact/$total))))
	#echo $fragpercentage > results_age/results_"$1"_fragpercent_"$2"g.txt
}

function posttestme(){
	fsname=f2fs
	if [[ "$(echo $1 | grep ext4)" ]]; then
		fsname=ext4
	fi
	if [[ "$(echo $1 | grep xfs)" ]]; then
		fsname=xfs
	fi
	
	# free memory before test
	sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

	#../blktrace_results/traceme_"$name".sh "$1"_"$2"g &
	#blkcheck=$!
	echo begin check "$1"...
	smartctl -A /dev/"$5" &> results_age/results_"$1"_smartctl_begin_"$2"g.txt
	iostat | grep "$5" > results_age/results_"$1"_iostat_begin_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_"$1"_f2fsstat_begin_"$2"g.txt
	fi
	# 100mb ftrace before
	#echo begin first trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_"$1"_ftracea_"$2"g.txt
	#rm trace.dat
	# main load
	#./run_bench_age.sh 725501 false "$4" > /dev/null
	echo run readseq "$2"g
	#./run_bench_age.sh "$3" false "$4" "$1" "$2"	
	myoutput=results_age/results_"$1"_"$2"g.txt
	./run_bench_age.sh "$3" false "l1" "$1" "$2" "readseq" &> $myoutput
	# 100mb ftrace after
	#echo begin second trace
	#trace-cmd record -e "$fsname" ./run_bench_age.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results_age/results_"$1"_ftraceb_"$2"g.txt
	#rm trace.dat
	smartctl -A /dev/"$5" &> results_age/results_"$1"_smartctl_end_"$2"g.txt
	iostat | grep "$5" > results_age/results_"$1"_iostat_end_"$2"g.txt
	if [[ -f /sys/kernel/debug/f2fs/status ]]; then
		sh -c "cat /sys/kernel/debug/f2fs/status" > results_age/results_"$1"_f2fsstat_end_"$2"g.txt
	fi
	#killall blktrace

	# check fragmentation
	fragperlevel $myoutput > results_age/results_age_"$1"_fragpercent_level_"$2"g.txt
	filefrag /home/jeongho/mnt/* | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_total_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep sst | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_sst_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep buf | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_buf_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep log | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results_age/results_"$1"_fragpercent_log_"$2"g.txt
	#intact=$(($(filefrag /home/jeongho/mnt/* | grep "1 extent\|0 extent" | wc -l)*100))
	#total=$(filefrag /home/jeongho/mnt/* | wc -l)
	#fragpercentage=$((100-$(($intact/$total))))
	#echo $fragpercentage > results_age/results_"$1"_fragpercent_"$2"g.txt
}

#for each workloads
# $1 = num
# $2 = workload type

	# with no ssr
	#echo testing nossr...
	#./"$name"_f2fs_nossr.sh
	#testme "nossr" "$x" "$dataset" "l0" "$devicename"

init "sata" "sdb1"

exit

for x in 32; do
	dataset_size=$x
	dataset=$((7255012*$dataset_size))
	freespace=$(($x/32*4096))
	echo dataset_size is $dataset_size
	
	#remove leftover blktrace
	#rm -f *blktrace*

	##real test
	
	
	# all of rocksdb on hot
	#echo testing ssr_steroids... with space bk1
	#./"$name"_f2fs_steroids.sh
	#testme "ssr_steroids_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	
	# all of rocksdb on cold
	#echo testing ssr_reverse... with space bk2
	#./"$name"_f2fs_reverse.sh
	#testme "ssr_reverse_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"

	
	#all files on cold
	# l1 cold
	#echo testing l1... with space bk1 fragcold
	#./"$name"_f2fs_ext_default.sh
	#./"$name"_f2fs_ext_default.sh
	#freespacemore
	#testme "l1_space_bk1_fragcold" "$x" "$dataset" "l1" "$devicename"

	#default zone
	# l1 cold
	#echo testing l1... with space bk1
	#./"$name"_f2fs_ext_default.sh
	#./"$name"_f2fs_ext_default.sh
	#freespacemore
	#testme "l1_space_bk1_default_l1" "$x" "$dataset" "l1" "$devicename"
	
	#default zone
	# l1 cold
	#echo testing l1... with space bk1
	#./"$name"_f2fs_ext_default.sh
	#./"$name"_f2fs_ext_default.sh
	#freespaceme
	#testme "l1_space_bk1_default_l1" "$x" "$dataset" "l1" "$devicename"
	
	
	#default zone
	# with ssr with space
	#echo testing ssr... with space bk1 h1
	#./"$name"_f2fs_default.sh
	#./"$name"_f2fs_default.sh
	#freespaceme
	#testme "ssr_space_bk1_default_h1" "$x" "$dataset" "h1" "$devicename"
	
	#default zone
	# l1 cold
	#echo testing l1... with space bk1
	#./"$name"_f2fs_ext_default.sh
	#./"$name"_f2fs_ext_default.sh
	#freespaceme
	#testme "l1_space_bk1_default_l1" "$x" "$dataset" "l1" "$devicename"
	#posttestme "l1_space_bk1_default_l1_readseq" "$x" "$dataset" "l1" "$devicename"
	
	#default zone
	# with ssr with space
	#echo testing ssr... with space bk1 h1
	#./"$name"_f2fs_default.sh
	#./"$name"_f2fs_default.sh
	#freespaceme
	#testme "ssr_space_bk1_default_l1" "$x" "$dataset" "l1" "$devicename"
	#posttestme "ssr_space_bk1_default_l1_readseq" "$x" "$dataset" "l1" "$devicename"
	
	# ext4 with space
	#echo testing ext4... with space bk1
	#./"$name"_ext4.sh
	#./"$name"_ext4.sh
	#freespaceme
	#testme "ext4_space_bk1_l1" "$x" "$dataset" "l1" "$devicename"
	posttestme "ext4_space_bk1_l1_readseq" "$x" "$dataset" "l1" "$devicename"
	
	
	#20GB zone
	# l1 cold
	#echo testing l1... with space bk1
	#./"$name"_f2fs_ext.sh
	#./"$name"_f2fs_ext.sh
	#freespaceme
	#pretestme "l1_space_bk1" "$x" "$dataset" "l1" "$devicename"
	#testme "l1_space_bk1" "$x" "$dataset" "l1" "$devicename"
	
	#20GB zone
	# with ssr with space
	#echo testing ssr... with space bk1
	#./"$name"_f2fs.sh
	#./"$name"_f2fs.sh
	#freespaceme
	#pretestme "ssr_space_bk1" "$x" "$dataset" "l1" "$devicename"
	#testme "ssr_space_bk1" "$x" "$dataset" "l1" "$devicename"
	
	
	
	#default zone
	# l1 hot
	#echo testing l1 reverse... with space bk1
	#./"$name"_f2fs_ext_reverse_default.sh
	#./"$name"_f2fs_ext_reverse_default.sh
	#freespaceme
	#pretestme "l1_space_bk1_reverse_default" "$x" "$dataset" "l1" "$devicename"
	#testme "l1_space_bk1_reverse_default" "$x" "$dataset" "l1" "$devicename"
	
	#20GB zone
	# l1 hot
	#echo testing l1 reverse... with space bk1
	#./"$name"_f2fs_ext_reverse.sh
	#./"$name"_f2fs_ext_reverse.sh
	#freespaceme
	#pretestme "l1_space_bk1_reverse" "$x" "$dataset" "l1" "$devicename"
	#testme "l1_space_bk1_reverse" "$x" "$dataset" "l1" "$devicename"
	

	

	
	
	
	
	
	
	
	
	# l1 hot
	#echo testing l1 hot... with space bk1
	#./"$name"_f2fs_ext_reverse.sh
	#testme "l1_space_reverse_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	#testme "l1_space_bk1" "$x" "$dataset" "x1" "$devicename" "space" "bk1"
	
	
	# with no ssr
	#echo testing nossr... bk2
	#./"$name"_f2fs_nossr.sh
	#testme "nossr_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# xfs with space
	#echo testing xfs... with space bk1
	#./"$name"_xfs.sh
	#testme "xfs_space_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"

	#trace after one run
	#blktraceme $x
	
done

#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)

