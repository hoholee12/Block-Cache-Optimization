#!/bin/bash
size=$(($(lsblk -b --output SIZE -n -d /dev/sdb)/1000000))
sudo fuser -k ~/mnt
sudo umount ~/mnt
sudo parted /dev/sdb rm 1 -s
sudo parted /dev/sdb mkpart primary 1MB "$size"MB -s
sync
