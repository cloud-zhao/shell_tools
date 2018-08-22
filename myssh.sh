#!/usr/bin/env bash
base=$(cd $(dirname $0);pwd)


dir=$HOME/cloudzhao/hosts

function __continue__(){
	local i=$1
	local j=$(echo $i | grep -E '^#' | wc -l)
	local k=$(echo $i | grep ':' | wc -l)
	if [ "x$i" == "x" ] || [ $j -ne 0 ] || [ $k -ne 0 ];then
		echo 1
	else
		echo 0
	fi
}

function _get_num(){
	local num=$1
	local nuu=()
	if [ $(echo $num | grep -E '[0-9]{1,}\.\.[0-9]{1,}' | wc -l) -ne 0 ];then
		nuu=($(echo $num | awk -F '\\.\\.' '{for(i=$1;i<=$2;i++){print i}}'))
		echo ${nuu[@]}
	else
		nuu=($(echo $num | awk '{for(i=1;i<=NF;i++){if($i~/[0-9]+/){print $i}}}'))
		echo ${nuu[@]}
	fi
}

function _get_host(){
	local file=$1
	local mode=${2:-1}
	local ii=()
	local user_a=()
	local ip_a=()
	local num i j
	echo "Host List :" >&2
	while read line
	do
		test $(__continue__ "$line") -ne 0 && continue
		ii=($(echo $line | awk '{for(i=1;i<=NF;i++){print $i}}'))
		if [ ${#ii[@]} -gt 3 ];then
			printf "\t%-3d IP: %-20s HOST: %s\n" "$i" "${ii[0]}" "${ii[3]}" >&2
		else
			printf "\t%-3d IP: %-20s HOST: %s\n" "$i" "${ii[0]}" "UNKNOWN" >&2
		fi
		user_a=(${user_a[@]} ${ii[1]})
		ip_a=(${ip_a[@]} ${ii[0]})
		let i=$i+1
	done < $file

	test ${#user_a[@]} -eq 0 && { echo -e "\tNot find role hosts" >&2;echo "q";return; }

	read -p "Please enter number: " -t 30 num
	test "x$num" == "x" && num="q"
	test "x$num" == "xq" && { echo "q";return; }
	ii=()
	for i in $(echo $num)
	do
		for j in $(_get_num $i)
		do
			test $j -ge ${#user_a[@]} && continue
			test $j -ge ${#ip_a[@]} && continue
			ii=(${ii[@]} ${user_a[$j]}@${ip_a[$j]})
		done
	done
	test $mode -eq 1 && {
		echo ${ii[0]};
		return;
	}
	echo ${ii[@]}
}

function _write_host(){
	local file=$dir/_all
	local ip=$1
	local u ro p h
	if [ $(echo $ip | grep '@' | wc -l) -eq 0 ];then
		u=$(grep $ip $file | awk '{print $2}')
		test "x$u" == "x" && {
			echo "$ip is not in the $file and user not set." >&2;
			exit;
		}
		echo "$u@$ip"
	else
		u=$(echo $ip | awk -F'@' '{print $1}')
		ip=$(echo $ip | awk -F'@' '{print $2}')
		test "x$u" == "x" && test "x$ip" == "x" && return
		read -p "Please enter hostname: " -t 60 h
		read -p "Please enter role: " -t 60 ro
		read -p "Please enter password: " -t 60 p
		test "x$ro" == "x" && ro="unknown"
		test "x$h" == "x" && h="unknown"
		test "x$p" == "x" && p="null"
		
		test $(grep $ip $file | wc -l) -eq 0 && echo "$ip  $u  $h  $p  $ro" >>$file
		echo "$u@$ip"
	fi
}

function _check_ip(){
	local i=$1
	local awk_code='{if(NF!=4){print 0}else{if($1>255 || $2>255 || $3>255 || $4>255){print 0}else{print 1}}}'
	echo "$i" | awk -F '.' "$awk_code"
}
function _get_all_hosts(){
	local role=$1
	local f="$base/.all_hosts.txt"
	test "x$role" != "x" && test -f "$dir/$role" && {
		echo "$dir/$role";
		return;
	}
	local i j k
	>$f
	for i in $(ls $dir | grep -vE '.sh$')
	do
		test ! -f "$dir/$i" && continue
		while read k
		do
			test $(__continue__ $k) -ne 0 && continue
			j=$(echo $k | awk '{for(i=4;i<=NF;i++){if(j){j=j"_"$i}else{j=$i}};print j}')
			if [ "x$role" != "x" ];then
				test $(echo $j | grep -i "$role" | wc -l) -ne 0 && {
					echo $k >>$f;
				}
			fi
		done < $dir/$i
	done
	echo $f
}
function __is__(){
	local p=$1
	if [ $(_check_ip $p) -eq 0 ] && [ $(_check_ip $(echo $p | awk -F '@' '{print $2}')) -eq 0 ];then
		echo 1
	else
		echo 2
	fi
}

function myssh(){
	local ip=$1
	local iss=()

	if [ "x$ip" == "x" ];then
		iss=($(_get_host $(_get_all_hosts)))
		test "x${iss[0]}" == "xq" && exit
		test "x${iss[0]}" == "x" && exit
		ssh ${iss[0]}
	else
		case $(__is__ $ip) in
			1)
				iss=($(_get_host $(_get_all_hosts $ip)))
				test "x${iss[0]}" == "xq" && exit
				test "x${iss[0]}" == "x" && exit
				ssh -o ConnectTimeout=10 ${iss[0]};;
			2)
				local l=$(_write_host $ip)
				test "x$l" != "x" && ssh -o ConnectTimeout=10 $l;;
			*)
				echo -e "Usage: myssh [role|ip|user@ip]"
		esac
	fi
}
function _exec(){
	local res ip
	for ip in $@
	do
		test "x$ip" == "x" && continue
		res=$(ssh -o ConnectTimeout=10 -n $ip "$cmd")
		if [ "x$res" == "x" ];then
			echo -e "$ip\t\tok"
		else
			echo -e "$ip\t\t$res"
		fi
	done
}

function mycmd(){
	local cmd=${1:-"echo 'ok'"}
	local ip=$2
	local res=""
	local iss=()

	if [ "x$ip" == "x" ];then
		iss=($(_get_host $(_get_all_hosts) 2))
		test "x${iss[0]}" == "xq" && exit
		test "x${iss[0]}" == "x" && exit
		_exec ${iss[@]}
	else
		case $(__is__ $ip) in
			2)
				local l=$(_write_host $ip)
				test "x$l" != "x" && {
					res=$(ssh -n $l "$cmd");
					echo -e "$i\t\t$res";
				};;
			1)
				iss=($(_get_host $(_get_all_hosts $ip) 2))
				test "x${iss[0]}" == "xq" && exit
				test "x${iss[0]}" == "x" && exit
				_exec ${iss[@]};;
		esac
	fi
}

function __scp__(){
	local ip u
	for ip in $@
	do
		test "x$ip" == "x" && continue
		u=$(echo $ip | awk -F'@' '{print $1}')
		if [ "x$target" == "x" ];then
			if [ "$u" == "root" ];then
				u="/$u/"
			else
				u="/home/$u/"
			fi
			scp -o ConnectTimeout=10 -r $file $ip:$u
		else
			scp -o ConnectTimeout=10 -r $file $ip:$target
		fi
	done
}

function myscp(){
	local file target ip iss
	case $# in
		1)	
			file=$1;;
		2)	
			file=$2
			ip=$1;;
		3)	
			ip=$1
			file=$2
			target=$3 ;;
		*)
			echo -e "Usage:\n\tmyscp [role] [file] [target]"
			return;;
	esac

	if [ "x$ip" == "x" ];then
		iss=($(_get_host $(_get_all_hosts) 2))
		test "x${iss[0]}" == "xq" && exit
		test "x${iss[0]}" == "x" && exit
		__scp__ ${iss[@]}
	else
		case $(__is__ $ip) in
			2)
				local l=$(_write_host $ip)
				test "x$l" != "x" && __scp__ $l;;
			1)
				iss=($(_get_host $(_get_all_hosts $ip) 2))
				test "x${iss[0]}" == "xq" && exit
				test "x${iss[0]}" == "x" && exit
				__scp__ ${iss[@]}
		esac
	fi
}

commands=$1;shift
case $commands in
	"myssh")
		myssh "$@";;
	"mycmd")
		mycmd "$@";;
	"myscp")
		myscp "$@";;
	*)
		echo -e "Usage:\n\tbash $0 [myssh|mycmd|myscp] [user@ip|role|]";;
esac
