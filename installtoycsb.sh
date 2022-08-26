#!/bin/bash

sudo make rocksdbjavastaticrelease -j3
cd ../YCSB
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
mvn -pl site.ycsb:rocksdb-binding -am clean package
cd ../rocksdb
cp java/target/rocksdbjni-6.24.0.jar /home/jeongho/.m2/repository/org/rocksdb/rocksdbjni/6.2.2/rocksdbjni-6.2.2.jar
cp java/target/rocksdbjni-6.24.0.jar /root/.m2/repository/org/rocksdb/rocksdbjni/6.2.2/rocksdbjni-6.2.2.jar
cp java/target/rocksdbjni-6.24.0.jar /home/jeongho/YCSB/rocksdb/target/dependency/rocksdbjni-6.2.2.jar
#echo "just a little test."
#cd ../YCSB
#./bin/ycsb load rocksdb -s -P workloads/workloada -p rocksdb.dir=/tmp/ycsb-rocksdb-data
