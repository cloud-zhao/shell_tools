#!/bin/bash

. /etc/profile

KFK_DEBUG=0
function debug(){
	test $KFK_DEBUG -eq 1 &&  echo -e "[DEBUG] $(caller 0 | awk '{print $1}') $@" >&2
}

function time_date(){
	/bin/date "+%Y-%m-%d %H:%M:%S"
}

function timestamp(){
	/bin/date "+%s"
}

function LOG(){
	local log_level=$1
	shift
	local log_str=("INFO" "WARN" "ERROR" "DEBUG")
	case ${log_str[$log_level]} in
		"DEBUG")
			test $KFK_DEBUG -eq 1 && echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $(time_date) $@" >&2;;
		*)
			echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $(time_date) $@" >&2;;
	esac
}



BASE=$(cd "$(dirname $0)";pwd)

LOG 3 $BASE

RATE=${1:-3}


function send_mail(){
	local sub=$1
	local body=$2
	local email=($(echo ${4:-"zhen.zhao@meelive.cn,lize.qian@meelive.cn"} | awk -F ',' '{for(i=1;i<=NF;i++){print $i}}'))
	local body_file=".send_mail_body_file_$(date +%s%N)_.out"

	echo -e "$body" >$body_file
	/bin/mail -s "$sub" ${email[@]} <$body_file
	rm -rf $body_file
}

function get_size(){
	local ser=${1:-"127.0.0.1:2181"}
	local topic=$2
	local group=$3
	local out="$BASE/.kafka_check_$(date +%s%N).out"
	local inof=""
	local res=()

	LOG 0 "Get $topic size."

	/opt/kafka/bin/kafka-consumer-offset-checker.sh --zookeeper $ser --topic $topic --group $group >$out 2>&1
	while read info
	do
		test $(echo $info | grep "$topic" | wc -l) -ne 1 && continue
		res=(${res[@]} $(echo $info | awk '{printf $1"_"$2"_"$3" "$5}'))
	done < $out

	rm -rf $out
	[ $? -eq 0 ] && LOG 3 "RM: $out ok"


	LOG 3 "RES: ${res[@]}"
	echo ${res[@]}
}

function join(){
	local str="GROUP_TOPIC_PARTITION#####OPS"
	local all=($@)
	local let index=${#all[@]}
	local let k_index=$index/2
	local keys=(${all[@]:0:$k_index})
	local vals=(${all[@]:$k_index:$index})
	LOG 3 "JOIN: ${keys[@]}"
	LOG 3 "JOIN: ${vals[@]}"
	local i=0;
	for ((i=0;i<${#keys[@]};i++))
	do
		str="$str\n${keys[$i]}######${vals[$i]}"
	done
	echo $str
}

function check(){
	local group=$1
	local topic=$2
	local flag=$3
	local contacts=$4
	[ $# -ne 4 ] && return
	local rate=$RATE
	local file="$BASE/.${group}_${topic}_${rate}.txt"
	declare -A topic_hash
	local o_topic=()
	local o_t_info=""
	declare -A ops
	local ops_p=0

	LOG 0 "Check start. (Group:$group Topic:$topic)"

	local res=($(get_size "" "$topic" "$group"))
	
	if [ ${#res[@]} -eq 0 ];then
		LOG 2 "Get $group $topic size failed."
		return
	else
		LOG 0 "Get $topic size successful."
	fi

	LOG 3 "Check_Res: ${res[@]}"
	
	for ((i=0;i<${#res[@]};i++))
	do
		topic_hash["${res[$i]}"]=${res[$i+1]}
		let i=$i+1
	done

	if [ ${#topic_hash[@]} -eq 0 ];then
		LOG 2 "Map topic hash failed."
		return
	else
		LOG 0 "Map topic hash successful."
	fi

	if [ -f $file ];then
		LOG 0 "Check old file."
		o_topic=($(cat $file))
		echo -n "" >$file
		for ((i=0;i<${#o_topic[@]};i++))
		do
			ops_p=$(echo "(${topic_hash[${o_topic[$i]}]}-${o_topic[$i+1]})/($rate*60)" | bc)
			if [ $ops_p -lt $flag ];then
				ops[${o_topic[$i]}]=$ops_p
			fi
			LOG 3 "OPS:${o_topic[$i]} ${topic_hash[${o_topic[$i]}]} $ops_p"
			echo "${o_topic[$i]} ${topic_hash[${o_topic[$i]}]}" >>$file
			let i=$i+1
		done
	else
		LOG 0 "Create old file"
		for i in ${!topic_hash[@]}
		do
			echo "$i ${topic_hash[$i]}" >>$file
			LOG 3 "TOPIC_HASH: $i ${topic_hash[$i]}"
		done
	fi

	if [ ${#ops[@]} -ne 0 ]
	then
		LOG 0 "Send mail."
		LOG 3 "OPS: ${!ops[@]} ${ops[@]}"
		send_mail "Kafka OPS Warning" $(join "${!ops[@]}" "${ops[@]}") "$contacts"
	fi

	LOG 0 "Check stop."
}

function read_conf(){
	local conf=$1
	local info=""
	local config=()
	local config_tmp=()
	while read info
	do
		test $(echo $info | grep '#' | wc -l) -eq 1 && continue
		test $(echo $info | grep '|' | wc -l) -ne 1 && continue
		
		LOG 3 "Info: $info"
		config_tmp=($(echo $info | awk -F '|' '{printf $1"\t"$2"\t"$3"\t"$4}'))
		if [ ${#config_tmp[@]} -eq 4 ];then
			config=(${config[@]} ${config_tmp[@]})
		else
			LOG 1 "Configure $info fromat error."
		fi
	done < $conf

	LOG 3 "CONF: ${config[@]}"
	if [ ${#config[@]} -eq 0 ];then
		LOG 2 "Configure file $conf format error\tFormat:group_id|topic_name|partition|min_nrom,max_nrom|mail1,mail2"
		exit
	fi

	echo "${config[@]}"
}


function main(){
	LOG 0 "Main start."

	local conf=($(read_conf ${1:-"monitor_kafka.conf"}))
	local i=0

	LOG 3 "Conf: ${conf[@]}"
	for ((i=0;i<${#conf[@]};i++))
	do
		LOG 3 "Check: ${conf[$i]} ${conf[$i+1]} ${conf[$i+2]} ${conf[$i+3]}"
		check ${conf[$i]} ${conf[$i+1]} ${conf[$i+2]} "${conf[$i+3]}"
		let i=$i+3
	done

	LOG 0 "Main stop."
}


main ./xxx.conf
