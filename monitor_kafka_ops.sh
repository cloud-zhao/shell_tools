#!/bin/bash
#Support kafka version 0.8.2.1
#export KAFKA_HOME=xxx
#Configure file Format:
#	group_id|topic_name|partition|min_nrom,max_nrom|mail1,mail2|zookeeper_ser

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

RATE=${1:-1}


function send_mail(){
	local sub=$1
	local body=$2
	local email=($(echo ${3:-"zhen.zhao@meelive.cn,lize.qian@meelive.cn"} | awk -F ',' '{for(i=1;i<=NF;i++){print $i}}'))
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

	if [ -z $KAFKA_HOME ];then
		KAFKA_HOME='/opt/kafka'
	fi
	if [ -f $KAFKA_HOME/bin/kafka-consumer-offset-checker.sh ];then	
		LOG 0 "Get $topic size."
	else
		LOG 2 "Not found $KAFKA_HOME/bin/kafka-consumer-offset-checker.sh"
		exit
	fi


	$KAFKA_HOME/bin/kafka-consumer-offset-checker.sh --zookeeper $ser --topic $topic --group $group >$out 2>&1

	if [ $(cat $out | grep "KeeperException" | wc -l) -eq 1 ];then
		LOG 3 "Res zookeeper error $(cat $out)"
		LOG 2 "Res zookeeper error $(cat $out)"
		echo ${res[@]}
		return
	fi
	if [ $(cat $out | grep "$topic" | wc -l) -eq 0 ];then
		LOG 2 "Res zookeeper error $(cat $out)"
		echo ${res[@]}
		return
	fi
	res=($(cat $out | grep "$topic" | awk '{aa[$2]+=$5}END{for(i in aa){print i" "aa[i]}}'))

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
	local kfk_ser=$5
	[ $# -lt 5 ] && return
	local rate=$RATE
	local file="$BASE/.${group}_${topic}_${rate}.txt"
	local topic_hash=()
	local o_topic=()
	local ops_p=0
	local max=$(echo $flag | awk -F ',' '{print $2}')
	local min=$(echo $flag | awk -F ',' '{print $1}')

	LOG 0 "Check start. (Group:$group Topic:$topic)"

	local res=($(get_size "$kfk_ser" "$topic" "$group"))
	
	if [ ${#res[@]} -ne 2 ];then
		LOG 2 "Get $group $topic size failed."
		return
	else
		LOG 0 "Get $topic size successful."
	fi

	LOG 3 "Check_Res: ${res[@]}"
	
	topic_hash=(${res[0]} ${res[1]})

	if [ -f $file ];then
		LOG 0 "Check old file."
		o_topic=($(cat $file))
		if [ ${#o_topic[@]} -ne 2 ];then
			LOG 2 "Get old topic file failed."
			o_topic=($topic 0)
		else
			LOG 3 "Get old topic file successful. ${o_topic[@]}"
		fi
		ops_p=$(echo "${topic_hash[1]}-${o_topic[1]}" | bc)
		LOG 3 "OPS:${topic_hash[0]} $ops_p"
		echo "${topic_hash[0]} ${topic_hash[1]}" >$file
	else
		LOG 0 "Create old file"
		echo "${topic_hash[0]} ${topic_hash[1]}" >$file
		LOG 3 "TOPIC_HASH: ${topic_hash[@]}"
		ops_p=1
	fi

	LOG 3 "Check OPS: $ops_p"

	if [ $ops_p -lt $min ] || [ $ops_p -gt $max ]
	then
		LOG 0 "Send mail."
		LOG 3 "Contacts: $contacts"
		send_mail "Kafka OPS Warning" "$topic $(time_date)" "$contacts"
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
		config_tmp=($(echo $info | awk -F '|' '{printf $1"\t"$2"\t"$3"\t"$4"\t"$5}'))
		if [ ${#config_tmp[@]} -eq 5 ];then
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
		check ${conf[$i]} ${conf[$i+1]} ${conf[$i+2]} "${conf[$i+3]}" "${conf[$i+4]}"
		let i=$i+4
	done

	LOG 0 "Main stop."
}


main $BASE/xxx.conf
