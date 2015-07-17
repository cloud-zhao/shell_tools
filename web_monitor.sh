#!/bin/bash
. tools.sh

conf='webser.conf'
log='web_monitor.log'
date=`date "+%Y-%m-%d %H-%M-%S"`
to_mail='xxxx@xxx.xx'
cc_mail='xxx@xxx.xx'

if [ ! -f $conf ]
then
	exit
fi

function splitstr(){
	local srcstr=$1
	local substr=$2

	local result=(`echo $srcstr | awk -F "$2" '{for(i=1;i<=NF;i++){print $i}}'`)

	echo ${result[@]}
}

cat $conf | while read url
do
	host=`echo $url | awk -F '/' '{print $3}'`
	res=`curl -o /dev/null -s -w %{http_code}:%{time_namelookup}:%{time_connect}:%{time_starttransfer}:%{time_total}"\n" $url`
	res=(`splitstr $res ":"`)
	http_code=${res[0]}
	time_name=${res[1]}
	time_conn=${res[2]}
	time_star=${res[3]}
	time_total=${res[4]}
	time_all=`echo "$time_name+$time_conn+$time_star+$time_total" | bc | awk '{printf "%.3f", $0}'`
	if [ $http_code -ne 200 ]
	then
		sendmail "$host 404" "$host:$http_code:$time_all" $to_mail $cc_mail
	fi

	echo "$date $host $http_code $time_all" >>$log
done
