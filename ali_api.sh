#!/bin/bash
# Before you can use the tool, 
# you need to install following software.
# curl  openssl  gawk

if [ "$mode_ali_api" ];then
	return
fi
export mode_ali_api=1

function urlencode(){
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
            if ( c ~ /[a-zA-Z0-9._~-]/ ) {
                encoded = encoded c             # safe character
            } else if ( c == " " ) {
                encoded = encoded "%20"   # special handling
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
	local para_str=(`array $1`)
	local key=$2

	para_str=(`para_sort ${para_str[@]}`)

	local para_join=`para_join ${para_str[@]}`

	local srcstr="$para_join"
	srcstr="GET&"$(urlencode '/')"&"$(urlencode $srcstr)

	_strkey $srcstr "${key}&"

}

function _check_variable(){
	if [ -z "$URL" ] || [ -z "$ID" ] || [ -z "$KEY" ] || [ -z "$OUTFILE" ] || [ -z "$FT" ]
	then
		echo '
		#####Instances interface###########################
		# Use this interface to set the global variable   #
		# Example:                                        #
		#     URL ="ecs.aliyuncs.com"                     #
		#     ID  ="self id"                              #
		#     KEY ="self key"                             #
		#     FT ="XML/JSON"                              #
		#     OUTFILE="./json.txt"                        #
		###################################################
		'
		exit
	fi
}

function ali_api(){
	_check_variable

	[ $# -lt 1 ] && { echo "Parameter error!" >&2 ; exit; }

	local id=$ID
	local key=$KEY
	local url=$URL
	local ft=$FORMAT
	local interface=$1 ; shift
	local interface_para=($(echo $@))

	local para_array=('Version' '2014-05-26'
       		 	'Format' $FT 
			'SignatureNonce' $(cat /proc/sys/kernel/random/uuid) 
			'Timestamp' `date -d -8hour +%Y-%m-%dT%H:%M:%SZ`
		       	'SignatureMethod' 'HMAC-SHA1' 
			'SignatureVersion' '1.0')
	para_array=(${para_array[@]} 
		"Action" "$interface" 
		"AccessKeyId" $id 
		${interface_para[@]})

	local i=0
	while [ $i -lt ${#para_array[@]} ]
	do
		para_array[$i]=`urlencode ${para_array[$i]}`
		let i=$i+1
	done

	local sigstr=`signstr "para_array" $key`
	para_array=(${para_array[@]} "Signature" `urlencode $sigstr`)

	local parastr=`para_join ${para_array[@]}`

	local req="https://$url/?$parastr"
	echo $req

	echo ""

	curl -s $req -o $OUTFILE

	echo ""
}

