#!/bin/bash
size=$(($(lsblk -b --output SIZE -n -d /dev/nvme0n1)/1000000))
sudo fuser -k ~/mnt
sudo umount ~/mnt
sudo parted /dev/nvme0n1 rm 1 -s
sudo parted /dev/nvme0n1 mkpart primary 1MB "$size"MB -s
sync
