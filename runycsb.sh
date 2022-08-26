#!/bin/bash

workloadhere=$1
counthere=$2
locationhere=$3
typehere=$4

if [[ $workloadhere == "" ]]; then
	workloadhere="workloadc"
fi
if [[ $counthere == "" ]]; then
	counthere="1000000"
fi
if [[ $locationhere == "" ]]; then
	locationhere="/home/jeongho/mnt/"
fi
if [[ $typehere == "" ]]; then
	typehere="load"
fi

cp java/target/rocksdbjni-6.24.0.jar /home/jeongho/.m2/repository/org/rocksdb/rocksdbjni/6.2.2/rocksdbjni-6.2.2.jar
cp java/target/rocksdbjni-6.24.0.jar /root/.m2/repository/org/rocksdb/rocksdbjni/6.2.2/rocksdbjni-6.2.2.jar
cp java/target/rocksdbjni-6.24.0.jar /home/jeongho/YCSB/rocksdb/target/dependency/rocksdbjni-6.2.2.jar
cd ../YCSB
if [[ $typehere == "load" ]]; then
	echo "load..."
	./bin/ycsb load rocksdb -s -P workloads/$workloadhere -p recordcount=$counthere -p operationcount=$counthere -p rocksdb.dir=$locationhere
else
	echo "run..."
	./bin/ycsb run rocksdb -s -P workloads/$workloadhere -p recordcount=$counthere -p operationcount=$counthere -p rocksdb.dir=$locationhere
fi
