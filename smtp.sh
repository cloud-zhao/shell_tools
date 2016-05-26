#!/bin/bash

function connect(){
	local host=$2
	local port=$3
	local socket=$1

	eval "exec $socket<>/dev/tcp/$host/$port"
}

function close(){
	local socket=$1
	eval "exec $socket>&-"
	eval "exec $socket<&-"
}

function socket_is_ok(){
	local socket=$1
	local flag=$(ls /proc/self/fd | grep "$socket" | wc -l)
	if [ $flag -eq 0 ];then
		echo "fail"
	else
		echo "ok"
	fi
}

function read_socket(){
	local socket=$1

	while read -u $socket -t 1 reply
	do
		echo -ne "$reply\n"
	done
}

function write_socket(){
	local socket=$1
	local data=$2

	printf "$data" >&$socket
}

function mime_encode(){
	local str=$1

	echo -e "$str" | awk -F '' '
	BEGIN{
		j=0;
		for(i=65;i<91;i++){
			bl[j]=sprintf("%c",i);
			j++
		};
		for(i=97;i<123;i++){
			bl[j]=sprintf("%c",i);j++
		};
		for(i=0;i<=9;i++){
			bl[j]=i;j++
		};
		bl[j++]="+";
		bl[j]="/";
		for(i=0;i<256;i++){ascii[sprintf("%c",i)]=i}
		}
	function d2b(b,a,c,f){
		a="";
		while(b){a=b%2 a;b=int(b/2)};
		f="";
		for(c=0;c<(8-length(a));c++){f=0""f};
		return f""a
	}
	function b2d(a,b,c,f){
		b=length(a);c=0;
		for(f=1;f<=b;f++){c+=c;if(substr(a,f,1)=="1")c++};
		return c
		}
	{
		arg=""
		for(i=1;i<=NF;i++){
			arg=arg""d2b(ascii[$i])
		}
		for(i=1;i<=length(arg);i+=6){
			as="00"substr(arg,i,6)
			las=length(as)
			for(j=0;j<8-las;j++){
				as=as"0"
			}
			arc=arc""bl[b2d(as)]
		}
		ap=(6-(NF*8%6))/2
		printf arc
		if(ap==2){
			printf "=="
		}else if(ap==1){
			printf "="
		}
		print ""
	}'
}

function debug(){
	local str=$1
	if [ ${SMTP_DEBUG:-0} -ne 0 ];then
		echo -e "DEBUG\t$str"
	fi
}

function check_result(){
	local res=$1
	local flag1=$(echo $res | grep 250 | wc -l)
	local flag2=$(echo $res | grep 235 | wc -l)
	local flag3=$(echo $res | grep 334 | wc -l)

	if [ ${flag1} -ne 0 ];then
		echo "ok"
	elif [ ${flag2} -ne 0 ];then
		echo "ok"
	elif [ ${flag3} -ne 0 ];then
		echo "ok"
	else
		echo "fail"
	fi
}

function check_auth(){
	local res=$1

	if [ $(check_result "$res") == "fail" ];then
		echo "fail"
		return 0
	fi
	
	if [ $(echo $res | grep -i $2 | wc -l) -ne 0 ];then
		echo "ok"
	else
		echo "fail"
	fi
}

function _send(){
	local socket=$1
	local data=$2

	write_socket $socket "$data\r\n"
	local res=$(read_socket $socket)

	if [ $(check_result "$res") == "ok" ];then
		echo $res
		debug $res
	else
		echo $res
		exit
	fi

}

function send_mail(){
	local user=$1
	local pass=$2
	local to=$3
	local subject=$4
	local body=$5
	local socket="25"
	local host=${6:-"smtp.exmail.qq.com"}
	local port=${7:-"25"}
	local tos=($(echo $to | awk -F ',' '{for(i=1;i<=NF;i++){print $i}}'))

	debug "host $host"
	debug "port $port"
	debug "user $user"
	debug "pass $pass"
	debug "to $to"
	debug "subject $subject"
	debug "body $body"

	#exit

	connect $socket $host $port
	if [ $(socket_is_ok $sokcet) == "fail" ];then
		echo "Connect $host:$port failed!!!"
		exit
	fi

	local plain="AUTH ALAIN "$(mime_encode "\0$user\0$pass")"\r\n"

	read_socket $socket
	write_socket $socket "EHLO `hostname -s`\r\n"
	ehlo_res=$(read_socket $socket)
	if [ $(check_auth "$ehlo_res" "login") == "ok" ];then
		local user_code=$(mime_encode $user)
		local pass_code=$(mime_encode $pass)

		debug "user_code $user_code"
		debug "pass_code $pass_code"
		debug "$ehlo_res"

		write_socket $socket "AUTH LOGIN\r\n"
		read_socket $socket
		write_socket $socket "$user_code\r\n"
		read_socket $socket
		write_socket $socket "$pass_code\r\n"
		read_socket $socket
		write_socket $socket "mail from:<$user>\r\n"
		read_socket $socket
		for ((i=0;i<${#tos[@]};i++))
		do
			write_socket $socket "rcpt to:<${tos[$i]}>\r\n"
			read_socket $socket
		done
		write_socket $socket "data\r\n"
		read_socket $socket
		write_socket $socket "From:$user\r\n"
		write_socket $socket "To:$to\r\n"
		write_socket $socket "Subject:$subject\r\n"
		write_socket $socket "mail body\r\n\r\n\r\n"
		write_socket $socket "$body\r\n\r\n\r\n"
		write_socket $socket ".\r\n"
		read_socket $socket
		write_socket $socket "quit\r\n"
		read_socket $socket
	else
		echo $ehlo_res
	fi


	close $socket

}


