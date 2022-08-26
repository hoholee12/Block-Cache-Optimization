#!/bin/bash
size=$(($(lsblk -b --output SIZE -n -d /dev/nvme0n1)/1000000))
sudo fuser -k ~/mntbackup
sudo umount ~/mntbackup
sudo parted /dev/nvme0n1 rm 1 -s
sudo parted /dev/nvme0n1 mkpart primary 1MB "$size"MB -s
sync
sleep 1
mkfs.ext4 /dev/nvme0n1p1 -F
mount -t ext4 -o data=ordered /dev/nvme0n1p1 ~/mntbackup
chown jeongho:jeongho ~/mntbackup
