#!/bin/bash

KFK_LAG_DEBUG=1

function debug(){
	test $KFK_LAG_DEBUG -eq 1 &&  echo "[DEBUG] $(caller 0 | awk '{print $1}') $@" >&2
}

function send_mail(){
	local sub=$1
	local body=$2
	local email=$3
	local body_file=".send_mail_body_file_$(date +%s%N)_.out"

	echo -e "$body" >$body_file
	/bin/mail -s "$sub" $email <$body_file
	rm -rf $body_file
}

function get_lag(){
	local ser=${1:-"127.0.0.1:2181"}
	local topic=$2
	local group=$3
	local out=".kafka_check_$(date +%s%N).out"
	local inof=""
	local res=()

	/opt/kafka/bin/kafka-consumer-offset-checker.sh --zookeeper $ser --topic $topic --group $group >$out 2>&1
	while read info
	do
		test $(echo $info | grep "$topic" | wc -l) -ne 1 && continue
		res=(${res[@]} $(echo $info | awk '{printf $1" "$2" "$3" "$4" "$5;if($6=="unknown"){printf " "$5}else{print " "$6}}'))
	done < $out

	rm -rf $out

	debug "RES: ${res[@]}"
	echo ${res[@]}
}

function join(){
	local str="GROUP#####TOPIC#####PARTITION#####LAG"
	local warn=($@)
	local i=0;
	for ((i=0;i<${#warn[@]};i++))
	do
		str="$str\n${warn[$i]}"
	done
	echo $str
}

function check(){
	local group=$1
	local topic=$2
	local flag=$3
	local contacts=$4

	local res=($(get_lag "" "$topic" "$group"))
	local warns=()
	for ((i=0;i<${#res[@]};i++))
	do
		if [ ${res[$i+5]} -gt $flag ];then
			warns=(${warns[@]} "${res[$i]}#####${res[$i+1]}#####${res[$i+2]}#####${res[$i+5]}")
		fi
		let i=$i+5
	done
	if [ ${#warns[@]} -ne 0 ]
	then
		send_mail "Kafka Lag Warning" $(join ${warns[@]}) "$contacts"
	fi
}

function read_conf(){
	local conf=$1
	local info=""
	local config=()
	while read info
	do
		test $(echo $info | grep '#' | wc -l) -eq 1 && continue
		test $(echo $info | grep '|' | wc -l) -ne 1 && continue
		
		debug "Info: $info"
		config=(${config[@]} $(echo $info | awk -F '|' '{printf $1"\t"$2"\t"$3"\t"$4}'))
	done < $conf
	debug "CONF: ${config[@]}"
	echo "${config[@]}"
}


function main(){
	local conf=($(read_conf ${1:-"monitor_kafka.conf"}))
	local i=0

	debug "Conf: ${conf[@]}"
	for ((i=0;i<${#conf[@]};i++))
	do
		debug "Check: ${conf[$i]} ${conf[$i+1]} ${conf[$i+2]} ${conf[$i+3]}"
		check ${conf[$i]} ${conf[$i+1]} ${conf[$i+2]} "${conf[$i+3]}"
		let i=$i+3
	done


}


main ./xxx.conf
