#!/bin/bash

./sata_partition.sh

#mnt
if [[ "$(fuser -cu ~/mnt 2>&1 | wc -c)" -le 15 ]]; then
	fuser -ck ~/mnt
fi
umount ~/mnt 2>/dev/null
sleep 1
mkfs.xfs /dev/sdb1 -f
mount -t xfs /dev/sdb1 ~/mnt
chown jeongho:jeongho ~/mnt

df -T | grep mnt

