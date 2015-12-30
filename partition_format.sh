#!/bin/bash
. /etc/profile

disk=$1
mount=$2

fdisk $disk <<EOF
n
p
1


w
EOF
mkfs.ext4 ${disk}1 >/dev/null 2>&1
mkdir -p $mount
mount $disk $mount
echo "$disk            $mount              ext4       defaults		 0 0">>/etc/fstab

rm -rf /etc/cron.d/pat
