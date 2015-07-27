#!/bin/bash

home=.
mysql_host=$home/mysql_hosts
mysql_cc=$home/mysql_return.cc
date=`date +%Y-%m-%d`

function mysql_cmd(){
	local host=$1
	local cmd=$2
	mysql -u$USER -p$PASSWORD -h${host:?NULL} -A --connect_timeout=30 -e "${cmd:?NULL}" >$mysql_cc 2>&1
}

function check_myslave(){
	local host=$1
	local check_file=$2
	local check_IO=`grep Slave_IO_Running ${check_file:?NULL} | awk -F ':' '{print $2}'`
	local check_SQL=`grep Slave_SQL_Running $check_file | awk -F ':' '{print $2}'`
	
	echo "MYSQL:${host:?NULL}"
	if [ "$check_IO" == " Yes" ]
	then
		echo -e "\tSlave_IO_Runnings:Yes"
		if [ "$check_SQL" != " Yes" ]
		then
			echo -e "\tSlave_SQL_Running:ERROR"
			mysql_cmd $host 'stop slave;set global sql_slave_skip_counter=1;start slave;show slave status\G'
			check_myslave $host $check_file
		else
			echo -e "\tSlave_SQL_Running:Yes"
		fi
	else
		echo -e "\tSlave_IO_Running:$check_IO"
	fi
}

while read host_info
do
	host_ip=`echo $host_info | awk '{print $1}'`
	host_role=`echo $host_info | awk '{print $2}'`
	mysql_cmd $host_ip 'select curdate();'
	if [ "`tail -1 $mysql_cc`" == "$date" ]
	then
		echo "MYSQL:$host_ip is available"
		if [ "$host_role" == "slave" ]
		then
			echo "Check slave..........."
			mysql_cmd $host_ip 'show slave status\G'
			check_myslave $host_ip $mysql_cc
		fi
	else
		echo "MYSQL:$host_ip not available"
	fi
done <$mysql_host
