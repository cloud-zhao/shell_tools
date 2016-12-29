#!/usr/bin/env bash
. /etc/profile
. $HOME/.bash_profile
base=$(cd $(dirname $0);pwd)

function get_hostname(){
	hostname -s
}

function get_hostip(){
	/sbin/ifconfig -a | grep 'inet addr' | grep -v '127.0.0.1' | awk '{split($2,aa,":");print aa[2]}'
}

function mysql_exec(){
	local sql=$1
	local user="inke_cmdb"
	local password="inke_bd_cmdb"
	local database="inke_bd_cmdb"
	local host="127.0.0.1"
	local mysql_bin="/usr/bin/mysql"
	local res=()
	local res_code=1

	if [ "x$USER" == "xroot" ];then
		host="59.110.6.122"
	elif [ "x$USER" == "xgigi_hadoop" ];then
		host="10.27.64.160"
	fi

	res=($($mysql_bin -u$user -p$password -D$database -h$host -e "$sql"))
	res_code=$?

	if [ $res_code -eq 0 ];then
		res=(0 ${res[@]})
	else	
		res=($res_code ${res[@]})
	fi

	echo ${res[@]}
}

function get_hostrole(){
	local history_file=${1:-"$base/.host_report.txt"}
	local role_list=("DN" "org.apache.hadoop.hdfs.server.datanode.DataNode"
			 "NM" "org.apache.hadoop.yarn.server.nodemanager.NodeManager"
			 "RM" "org.apache.hadoop.yarn.server.resourcemanager.ResourceManager"
			 "NN" "org.apache.hadoop.hdfs.server.namenode.NameNode"
			 "HS" "org.apache.spark.deploy.history.HistoryServer"
			 "KAFKA" "kafka.Kafka"
			 "KAFKAM" "play.core.server.ProdServerStart|kafka-manager"
			 "CODIS" "codis-"
			 "FLUME" "org.apache.flume.node.Application"
			 "MYSQL" "mysqld|datadir"
	)

	local roles=()
	local i gs command_str history_str

	if [ -f $history_file ];then
		history_str="$(cat $history_file)"
	else
		history_str="NULL"
	fi

	for ((i=0;i<${#role_list[@]};i++))
	do
		gs=$(echo ${role_list[$i+1]} | awk -F '|' '{for(i=1;i<=NF;i++){if(!s){s="grep \""$i"\""}else{s=s" | grep \""$i"\""}};print s}')
		command_str="ps -ef | $gs | grep -v 'grep' | wc -l"
		if [ $(eval $command_str) -ne 0 ];then
			if [ $(echo $history_str | grep ${role_list[$i]} | wc -l) -eq 0 ];then
				roles=(${roles[@]} ${role_list[$i]})
			fi
		fi
		let i=$i+1
	done

	echo ${roles[@]}
}

function sql_join(){
	local sql=$1;shift
	local id=$1;shift
	local values=($(echo $@))
	local i=""

	for i in ${values[@]}
	do
		sql=$sql"($id,'$i'),"
	done
	sql=${sql%,}';'

	echo "$sql"
}

function role_report(){
	local host_id=$1
	local history_file=$2
	local host_role=($(get_hostrole $history_file))
	local res=()

	[ ${#host_role[@]} -eq 0 ] && { return; }

	local add_role='insert into hosts_role (host_id,host_role) values '
	add_role="$(sql_join "$add_role" $host_id ${host_role[@]})"
	res=($(mysql_exec "$add_role"))

	[ ${res[0]} -eq 0 ] && { echo "${host_role[@]}"; }
}

function ip_report(){
	local host_id=$1
	local history_file=${2:-"$base/.host_report.txt"}
	local host_ip=($(get_hostip))
	local res=()
	local history_str="NULL"
	local i=""
	local return_ip=()

	if [ -f $history_file ];then
		history_str="$(cat $history_file)"
	fi

	for i in ${host_ip[@]}
	do
		if [ $(echo $history_str | grep "$i" | wc -l) -eq 0 ];then
			local add_ip='insert into hosts_ip (host_id,host_ip) values '"($host_id,'$i');"
			res=($(mysql_exec "$add_ip"))
	
			[ ${res[0]} -eq 0 ] && { return_ip=(${return_ip[@]} $i); }
		fi
	done

	echo "${return_ip[@]}"
}

function hostname_report(){
	local host_name=$1
	local host_user=$2
	local timestamp=$3
	local res=()
	local host_id=-1

	local check_host="select host_id from hosts where host_name='$host_name';"
	res=($(mysql_exec "$check_host"))
	[ ${res[0]} -ne 0 ] && { echo "hostname $host_name already exists" >&2;echo $host_id;return; }

	local add_host="insert into hosts (host_name,host_user,timestamp) values ('$host_name','$host_user','$timestamp');"
	res=($(mysql_exec "$add_host"))
	[ ${res[0]} -ne 0 ] && { echo "add host to mysql failed!" >&2;echo $host_id;return; }

	res=($(mysql_exec "$check_host"))
	[ ${res[0]} -ne 0 ] && { echo "get host_id failed";echo "-1";return; }

	echo ${res[2]}
}

function host_report(){
	local host_name=$(get_hostname)
	local host_user=$USER
	local timestamp=$(date +%s)
	local history_file="$base/.host_report.txt"
	local host_id add_host
	local res=()
	local host_role=()
	local host_ip=()

	if [ -f $history_file ];then
		local host_info=($(cat $history_file))

		if [ ${#host_info[@]} -ge 4 ];then
			host_id=${host_info[0]}
			host_role=($(role_report $host_id $history_file))
			host_ip=($(ip_report $host_id $history_file))
			res=($(mysql_exec "update hosts set timestamp='$timestamp' where host_id=${host_info[0]};"))
			[ ${res[0]} -eq 0 ] && { host_info[3]=$timestamp; }
			echo "${host_info[@]} ${host_ip[@]} ${host_role[@]}" > $history_file
			return
		else
			if [ "x${host_info[0]}" == "x-2" ];then
				res=($(mysql_exec "delete from hosts where host_name='$host_name'"))
			fi
		fi
	fi

	host_id=$(hostname_report $host_name $host_user $timestamp)
	[ $host_id -lt 0 ] && { echo "$host_id" > $history_file;return; }
	host_role=($(role_report $host_id $history_file))
	host_ip=($(ip_report $host_id $history_file))

	echo "$host_id $host_name $host_user $timestamp ${host_ip[@]} ${host_role[@]}" > $history_file
}

host_report
#get_hostrole


