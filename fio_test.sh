#!/bin/bash

fio --directory=/home/jeongho/mnt --name=fiotest --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap
