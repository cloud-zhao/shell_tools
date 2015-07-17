#!/bin/bash

url='cvm.api.qcloud.com/v2/index.php'
para_array=('Nonce' $RANDOM 'Timestamp' `date +%s` 'Region' 'sh')

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

if [ $# -lt 3 ]
then
	echo "para error"
	exit
fi

id=$1 ; shift
key=$1 ; shift
action=$1 ; shift
private_para=($@)

let private_count=${#private_para[@]}%2

if [ ${#private_para[@]} -eq 1 ]
then
	echo "para error"
	exit
fi

para_array=(${para_array[@]} "Action" $action "SecretId" $id ${private_para[@]})


sigstr=`signstr $url "para_array" $key`
para_array=(${para_array[@]} "Signature" $sigstr)

i=1
while [ $i -lt ${#para_array[@]} ]
do
	para_array[$i]=`urlencode ${para_array[$i]}`
	let i=$i+2
done

para_array=(`para_sort ${para_array[@]}`)
parastr=`para_join ${para_array[@]}`

req="https://$url?$parastr"
echo $req

curl $req -o json.txt

echo ""
