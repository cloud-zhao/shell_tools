#!/bin/bash

function min(){
	d=$1
	for i in $@
	do
		if [ `echo "$i < $d" | bc` -eq 1 ]
		then
			d=$i
		fi
	done
	echo $d
}

mysql_data_dir=$1

disk_space=`df -h $mysql_data_dir | tail -1 | awk '{print $5}' | awk -F '%' '{print $1}'`

while [ `echo "$disk_space > 80" | bc` -eq 1 ]
do
	if [ `ls $mysql_data_dir | grep 'mysql-bin' | wc -l` -le 3 ]
	then
		exit
	fi

	ids=(`ls $mysql_data_dir | grep 'mysql-bin' | grep -v 'index' | awk -F '.' '{print $2}'`)

	file="amysql-bin."`min ${ids[@]}`
	rm -rf ${mysql_data_dir%/}/$file
	
done
