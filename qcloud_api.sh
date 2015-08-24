#!/bin/bash

function urlencode()
{
    local encoded_str=`echo "$*" | awk 'BEGIN {
        split ("1 2 3 4 5 6 7 8 9 A B C D E F", hextab, " ")
        hextab [0] = 0
        for (i=1; i<=255; ++i) {
            ord [ sprintf ("%c", i) "" ] = i + 0
        }
    }
    {
        encoded = ""
        for (i=1; i<=length($0); ++i) {
            c = substr ($0, i, 1)
            if ( c ~ /[a-zA-Z0-9.-]/ ) {
                encoded = encoded c             # safe character
            } else if ( c == " " ) {
                encoded = encoded "+"   # special handling
            } else {
                # unsafe character, encode it as a two-digit hex-number
                lo = ord [c] % 16
                hi = int (ord [c] / 16);
                encoded = encoded "%" hextab [hi] hextab [lo]
            }
        }
        print encoded
    }' 2>/dev/null`
    echo $encoded_str
}

function array(){
	local array_name=$1
	local array='echo ${'$array_name'[@]}'
	eval $array
}

function _strkey(){
	local str=$1
	local key=$2
	local strkey=`echo -n "$str" | openssl sha1 -hmac "$key" -binary | base64`
	echo $strkey
}

function para_sort(){
	local para_array=($@)
	local i=0
	local tmp_file='./.tmp_para.txt'

	rm -rf $tmp_file

	if [ $# -gt 0 ];then
		while [ $i -le ${#para_array[@]} ]
		do
			local paraid=${para_array[$i]}
			let i=$i+1
			local paravs=${para_array[$i]}
			let i=$i+1
			echo "$paraid $paravs" >>$tmp_file
		done
	fi

	local sort_para=(`cat $tmp_file | gawk '{aa[$1]=$2}END{len=asorti(aa,bb);for(i=1;i<=len;i++){print bb[i]"\t"aa[bb[i]]}}'`)
	rm -rf $tmp_file
	echo ${sort_para[@]}
}

function para_join(){
	local sort_para=($@)
	local i=0
	local parastr=""

	while [ $i -lt $# ];do
		parastr=$parastr"${sort_para[$i]}="
		let i=$i+1
		parastr=${parastr}"${sort_para[$i]}&"
		let i=$i+1
	done
	echo ${parastr%&}
}

function signstr(){
	local url=$1
	local para_str=(`array $2`)
	local key=$3
	local i=0

	while [ $i -lt ${#para_str[@]} ]
	do
		para_str[$i]=`echo ${para_str[$i]} | sed 's/_/./'`
		let i=$i+2
	done

	para_str=(`para_sort ${para_str[@]}`)
	
	local para_join=`para_join ${para_str[@]}`

	local srcstr="GET$url?$para_join";

	_strkey $srcstr $key

}

function qcloud_api(){
	[ $# -lt 5 ] && ( echo "para error" ; exit )

	local url=$1 ; shift
	local id=$1 ; shift
	local key=$1 ; shift
	local zone=$1 ; shift
	local action=$1 ; shift
	local private_para=($(echo $@))

	let local private_count=${#private_para[@]}%2

	if [ $private_count -eq 1 ]
	then
		echo "para error"
		exit
	fi

	local para_array=('Nonce' $RANDOM 'Timestamp' `date +%s` 'Region' "$zone")
	para_array=(${para_array[@]} "Action" "$action" "SecretId" "$id" ${private_para[@]})

	local sigstr=`signstr $url "para_array" $key`
	para_array=(${para_array[@]} "Signature" $sigstr)

	local i=1
	while [ $i -lt ${#para_array[@]} ]
	do
		para_array[$i]=`urlencode ${para_array[$i]}`
		let i=$i+2
	done

	para_array=(`para_sort ${para_array[@]}`)
	local parastr=`para_join ${para_array[@]}`
	
	local req="https://$url?$parastr"
	echo $req

	curl -s $req -o json.txt

	echo ""
}

function parse_host(){
	local file="./json.txt"

	local all_json=$(awk -F ',' '{for(i=1;i<=NF;i++){if($i~/instanceName/){printf $i"->"};if($i~/Ip/){printf $i"->"};if($i~/instanceId/){printf $i"\n"}}}' $file)
	local all_jsons=()

	for i in ${all_json[@]}
	do
		all_jsons=(${all_jsons[@]} $i)
	done

	all_jsons[0]=$(echo ${all_jsons[0]} | sed 's/instanceSet"://')
	local hostinfo=""
	local instance_name=""
	local lan_ip=""
	local wan_ip=""
	local instance_id=""
	local i=0

	for ((i=0;i<${#all_jsons[@]};i++))
	do
		hostinfo=$(echo ${all_jsons[$i]} | sed -r 's/"|\{|\}|\[|\]//g')
		instance_name=$(echo $hostinfo | awk -F '->' '{print $1}' | awk -F ':' '{print $2}')
		lan_ip=$(echo $hostinfo | awk -F '->' '{print $2}' | awk -F ':' '{print $2}')
		wan_ip=$(echo $hostinfo | awk -F '->' '{print $3}' | awk -F ':' '{print $2}')
		instance_id=$(echo $hostinfo | awk -F '->' '{print $4}' | awk -F ':' '{print $2}')
		echo "$instance_name $lan_ip $wan_ip $instance_id"
	done
}
