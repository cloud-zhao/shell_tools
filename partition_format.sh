#!/usr/bin/env bash
. /etc/bashrc
. /etc/profile

function fdisk_p(){
	local disk=$1
	fdisk ${disk} <<EOF
n
p
1


w
EOF
}

function parted_p(){
	parted -s -m $1 mklabel gpt mkpart primary ext4 0% 100%
}

function is_gpt(){
	local f=$(fdisk -l $1 2>&1 | grep '^WARNING: GPT' | wc -l)
	echo $f
}

function part(){
	local disk=$1
	local mount=$2
	test ! -b $disk && return
	test -b ${disk}1 && return
	echo "partition ${disk}" >&2
	if [ $(is_gpt $disk) -eq 1 ];then
		parted_p $disk
	else
		fdisk_p $disk
	fi
	test -b ${disk}1 && {
		echo "mkfs ${disk}1" >&2;
		mkfs.ext4 ${disk}1 >/dev/null 2>&1;
		mkdir -p $mount;
		mount ${disk}1 $mount;
		local f=$(cat /etc/fstab | grep -E "^${disk}1" | wc -l);
		test $f -eq 0 && echo -e "${disk}1 \t $mount \t ext4 \t defaults \t 0 0" >>/etc/fstab;
	}
}

function main(){
	local prefix=${1:-"/dev/vd"};shift
	local mounts=${2:-"/data"};shift
	local j=1
	local i=""
	for i in "$@"
	do
		echo "create paritition $prefix$i" mount to  "/data$j"
		part "$prefix$i" "/data$j"
		let j=$j+1
	done
}

main /dev/vd /data {b..h}
