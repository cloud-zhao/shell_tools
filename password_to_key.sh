#!/bin/bash

[ $# -lt 2 ] && exit
password=$1
key_path=$2

#Usage: cat ip.txt | password_to_key.sh password private_key_file

while read ip
do
	pubkey=`cat ${key_path}`

	/usr/bin/expect <<EOF
	set timeout 30
	spawn ssh root@$ip "mkdir -p /root/.ssh && chmod 700 /root/.ssh && echo '$pubkey' >>/root/.ssh/authorized_keys && echo ok"
	expect {
		"*(yes/no)" {
			send "yes\n"
			expect {
				"*password:" {send "$password\n"}
			}
		}
		"*password:" {send "$password\n"}
	}
	expect eof
EOF

done
