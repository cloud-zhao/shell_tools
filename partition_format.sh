#!/usr/bin/env bash
. /etc/bashrc
. /etc/profile

function fdisk_p(){
	local disk=$1
	test -b ${disk}1 && return
	fdisk ${disk} <<EOF
n
p
1
w
EOF
}

function parted_p(){
	test -b ${1}1 && return
	parted -s -m $1 mklabel gpt mkpart primary ext4 0% 100%
}

function is_gpt(){
	local f=$(lsblk -b -o NAME,SIZE $1 | grep "$(basename $1)" | awk '{print $2}')
	if [ ${f:-0} -ge 3221225472000 ];then
		echo 1
	else
		echo 0
	fi
}

function part(){
	local disk=$1
	local mount=$2
	local force_mk=${3:-1}
	test ! -b $disk && return
	test -b ${disk}1 && test "$force_mk" == "1" && return
	echo "partition ${disk}" >&2
	if [ $(is_gpt $disk) -eq 1 ];then
		parted_p $disk
	else
		fdisk_p $disk
	fi
	test -f /usr/sbin/partx && /usr/sbin/partx -a $disk
	test -b ${disk}1 && {
		echo "mkfs ${disk}1" >&2;
		mkfs.ext4 ${disk}1 >/dev/null 2>&1;
		mkdir -p $mount;
		test $(df -h | grep $mount | wc -l) -eq 0 &&  mount ${disk}1 $mount;
		local f=$(cat /etc/fstab | grep -E "^${disk}1" | wc -l);
		test $f -eq 0 && echo -e "${disk}1 \t $mount \t ext4 \t defaults \t 0 0" >>/etc/fstab;
	}
}

function main(){
	local prefix=${1:-"/dev/vd"};shift
	local mounts=${1:-"/data"};shift
	local j=1
	local i=""
	for i in "$@"
	do
		echo "create paritition $prefix$i" mount to  "$mounts$j"
		part "$prefix$i" "$mounts$j" 2
		let j=$j+1
	done
}

#parameter 磁盘路径前缀 挂载路径前缀 磁盘编号
main /dev/vd /hadoop/data {b..q}
