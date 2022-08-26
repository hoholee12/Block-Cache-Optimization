#!/bin/bash

./sata_partition.sh

#mnt
if [[ "$(fuser -cu ~/mnt 2>&1 | wc -c)" -le 15 ]]; then
	fuser -ck ~/mnt
fi
umount ~/mnt 2>/dev/null
sleep 1
mkfs.ext4 /dev/sdb1 -F
mount -t ext4 -o data=ordered /dev/sdb1 ~/mnt
chown jeongho:jeongho ~/mnt

df -T | grep mnt
