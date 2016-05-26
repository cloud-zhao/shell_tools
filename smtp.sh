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
		printf "REPLY: $reply\n"
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


socket="25"
host="smtp.exmail.qq.com"
port="25"

connect $socket $host $port

if [ $(socket_is_ok $sokcet) == "fail" ];then
	echo "Connect $host:$port failed!!!"
	exit
fi

read_socket $socket
write_socket $socket "EHLO `hostname -s`\r\n"
read_socket $socket
write_socket $socket "auth login\r\n"
read_socket $socket
write_socket $socket "$user\r\n"
read_socket $socket
write_socket $socket "$pass\r\n"
read_socket $socket
write_socket $socket "data\r\n"
read_socket $socket
write_socket $socket "To:$to\r\n"
write_socket $socket "From:$from\r\n"
write_socket $socket "Subject:$subject\r\n"
write_socket $socket "mail body\r\n"
write_socket $socket "$body\r\n"
write_socket $socket ".\r\n"
read_socket $socket
write_socket $socket "quit\r\n"
read_socket $socket


close $socket


