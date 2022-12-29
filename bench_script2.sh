#!/bin/bash

KEY_SIZE=$1
VALUE_SIZE=$2
PREFIX_SIZE=$3
CACHE_SIZE=$4
SHARDBITS=$5
BLOOMBITS=$6
DB=$7
EXISTING=$8  # true of false

#echo $1 $2 $3 $4 $5 $6 $7

./db_bench --use_direct_io_for_flush_and_compaction=true --use_direct_reads=true --key_size=$KEY_SIZE --value_size=$VALUE_SIZE --prefix_size=$PREFIX_SIZE --cache_size=$CACHE_SIZE --cache_numshardbits=$SHARDBITS --bloom_bits=$BLOOMBITS --benchmarks="predefined" --db=$7
