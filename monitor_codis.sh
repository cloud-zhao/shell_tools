#!/bin/bash

date_time=$(date "+%Y-%m-%d %H:%M:%S")

function LOG(){
	local log_level=$1
	shift
	local time_date=$(date "+%Y-%m-%d %H:%M:%S")
	local log_str=("INFO" "WARN" "ERROR" "DEBUG")
	if [ -z $DEBUG ];then
		DEBUG=0
	fi
	case ${log_str[$log_level]} in
		"DEBUG")
			test $DEBUG -eq 1 && echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $time_date $@" >&2;;
		*)
			echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $time_date $@" >&2;;
	esac
}

function send_mail(){
	local sub=$1
	local body=$2

	/bin/mail -s "$sub" zhen.zhao@meelive.cn lize.qian@meelive.cn <<EOF
	$body
EOF
}

zookeeper_ser=${1:-"127.0.0.1:2181"}

function zookeeper_check(){
	local ser=$(/sbin/ifconfig em3 | grep 'inet addr' | awk '{split($2,a,":");print a[2]":6379"}')
	local pid=$(ps -ef | grep 'org.apache.zookeeper.server.quorum.QuorumPeerMain' | grep -v 'grep' | awk '{print $2}')
	
	if [ -z $pid ];then
		cd /opt/zookeeper
		/opt/zookeeper/bin/zkServer.sh start
		send_mail "Codis Zookeeper Stop" "$date_time codis $ser zookeeper process stop"
	else
		echo "zookeeper ok" >&2
	fi
}

function codis_check(){
	local proc=$1
	local ser=$(/sbin/ifconfig em3 | grep 'inet addr' | awk '{split($2,a,":");print a[2]":6379"}')
	local pid=$(ps -ef | grep "$proc" | grep -v 'grep' | grep -v 'monitor_codis.sh' | awk '{print $2}')

	if [ -z $pid ];then
		LOG 2 "codis process not exists"
		echo "false"
	else
		LOG 1 "codis process ok"
		echo "error"
		echo "codis process ok" >&2
	fi
}

function read_zoo(){
	local zk_root='/zk/codis/db_inke'
	local commands=$1
	local cmd=$(echo $commands | awk '{print $1}')
	local dir=$(echo $commands | awk '{print $2}')
	local ncommand="$cmd $zk_root/$dir"
	local zk_bin="/usr/local/bin/cli_mt $zookeeper_ser"
	local out="./.zk_cli_read_$(date +%s%N).out"
	local res="";

	$zk_bin "cmd:$ncommand" >$out 2>&1

	if [ $(grep 'rc = 0' $out | wc -l) -eq 1 ];then
		case $cmd in
			"get")
				res=$(cat $out | awk '{if($0~/value_len =/){f=1;j=0}else{j=1};if($0~/Stat:/){p=2};if(f==1 && p!=2 && j==1){print $0}}')
				echo $res;;
			"ls")
				res=($(cat $out | awk '{if($0~/rc = 0/){f=1}else{p=1};if($0~/time =/){p=2};if(f==1 && p==1){print $0}}'))
				echo ${res[@]};;
			*)
				echo "NULL";;
		esac
	fi

	rm -rf $out
}

function monitor(){
	local zk_root='/zk/codis/db_inke'
	local commands=$1
	local cmd=$(echo $commands | awk '{print $1}')
	local dir=$(echo $commands | awk '{print $2}')
	local ncommand="$cmd $zk_root/$dir"
	local zk_bin="/usr/local/bin/cli_mt $zookeeper_ser"
	local out="./.zk_cli_$(date +%s%N).out"

	LOG 0 "get zookeeper info"
	$zk_bin "cmd:$ncommand" >$out 2>&1
	if [ $(grep 'rc = 0' $out | wc -l) -eq 1 ];then
		LOG 0 "get zookeeper info successful"
		if [ $# -eq 3 ];then
			LOG 0 "check parameter num"
			if [ $(grep $2 $out | wc -l) -eq 1 ];then
				LOG 0 "monitor check ok"
				echo "true"
			else
				LOG 2 "monitor check failed"
				cat $out >&2
				echo "false"
			fi
		else
			LOG 0 "zookeeper res check ok"
			echo "true"
		fi
	else
		LOG 1 "get zookeeper info failed"
		if [ $(grep 'rc = -101' $out | wc -l) -eq 1 ];then
			LOG 2 "zookeeper not node"
			cat $out >&2
			echo "false"
		else
			LOG 1 "zookeeper other error"
			cat $out >&2
			LOG 1 "zookeeper service process check"
			zookeeper_check
			LOG 1 "codis service process codis check"
			if [ $# -eq 2 ];then
				codis_check $2
			elif [ $# -eq 3 ];then
				codis_check $3
			fi
		fi
	fi
	rm -rf $out
}

function restart_cmd(){
	local cmd=$1
	local pid=$(ps -ef | grep "$2" | grep -v 'grep' | grep -v 'monitor_codis' | awk '{print $2}')

	if [ ! -z $pid ];then
		echo "Kill -9 $pid" 
		/bin/kill -9 $pid
		if [ $? -eq 0 ];then
			echo "exec $cmd"
			$cmd
		fi
	else
		echo "exec $cmd"
		$cmd
	fi
}

function monitor_proxy(){
	local rc=$(monitor "get proxy/proxy_1" "online" $1)
	if [ $rc == "false" ];then
		LOG 2 "restart codis_proxy"
		restart_cmd "/opt/golang/src/github.com/CodisLabs/codis/start_codis_proxy" "codis-proxy"
		LOG 2 "check result failed send mail"
		send_mail "Codis Proxy Warnings" "$date_time codis proxy_1 restart"
	else
		LOG 0 "check result $rc"
	fi
}

function monitor_dash(){
	local rc=$(monitor "get dashboard" $1)
	if [ $rc == "false" ];then
		LOG 2 "restart dashboard"
		restart_cmd "/opt/golang/src/github.com/CodisLabs/codis/start_codis_dashboard" "dashboard"
		LOG 2 "check result failed send mail"
		send_mail "Codis Dashboard Warnings" "$date_time codis dashboard restart"
	else
		LOG 0 "check result $rc"
	fi
}

function monitor_ser(){
	local ser=$(/sbin/ifconfig em3 | grep 'inet addr' | awk '{split($2,a,":");print a[2]":6379"}')
	local ser_id=$(echo $ser | awk -F '' '{print $(NF-5)}')
	local rc=$(monitor "get servers/group_$ser_id/$ser" "master" $1)
	if [ $rc == "false" ];then
		LOG 2 "restart codis server"
		restart_cmd "/opt/golang/src/github.com/CodisLabs/codis/start_codis_server" "codis-server"
		LOG 2 "check result failed send mail"
		send_mail "Codis Server Warnings" "$date_time codis server $ser restart"
	else
		LOG 0 "check result $rc"
	fi
}

function main(){
	local role="$1"
	local roles=("codis-proxy" "codis-server" "dashboard")
	LOG 0 "runing check $role"
	case $role in
		${roles[0]})
			monitor_proxy $role;;
		${roles[1]})
			monitor_ser $role;;
		${roles[2]})
			monitor_dash $role;;
	esac
}


main "$2"
