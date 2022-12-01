#!/bin/bash

./nvme_partition.sh

#mnt
if [[ "$(fuser -cu ~/mnt 2>&1 | wc -c)" -le 15 ]]; then
	fuser -ck ~/mnt
fi
umount ~/mnt 2>/dev/null
sleep 1
mkfs.ext4 /dev/nvme0n1p1 -F
mount -t ext4 -o data=ordered /dev/nvme0n1p1 ~/mnt
chown mj123:mj123 ~/mnt

df -T | grep mnt
