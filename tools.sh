#!/bin/bash

function array(){
	local array_name=$1
	local array='echo ${'$array_name'[@]}'
	eval $array
}

function array_del(){
	[ $# -ne  1 ] && return
	local elem=$1
	local array_name=`echo $elem | awk -F '[' '{print $1}'`

	eval "unset $elem"
	local array=(`eval 'echo ${'$array_name'[@]}'`)
	local j=0
	local i
	local new_array
	for i in ${array[@]}
	do
		new_array[$j]=$i
		let j=$j+1
	done

	eval "$array_name=(`echo ${new_array[@]}`)"
}

function array_split(){
	[ $# -lt 2 ] && return
	local split=$1
	local str=$2

	local array=(`echo $str | awk -F "$split" '{for(i=1;i<=NF;i++){print $i}}'`)
	echo ${array[@]}
}

function array_join(){
	[ $# -lt 3 ] && return
	local join=$1 ; shift
	local str=$1 ; shift
	local array=($@)
	local i

	for i in ${array[@]}
	do
		str="${str}${join}${i}"
	done

	echo $str
}

function sendmail(){
	if [ $# -lt 3 ]
	then
		echo 1
		return
	fi
	local subject=$1
	local body=$2
	local to_mail=$3
	[ $# -eq 4 ] && local cc_mail=$4
	local ser='SELF SERVER'
	local user='SELF USER'
	local pass='SELF PASSWORD'

	local bin="/root/install/sendEmail"
	
	$bin/sendEmail -f $user -t $to_mail -cc $cc_mail -u $subject -m $body -s $ser -xu $user -xp $pass

}

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

function include(){
	local lib=$1

	if test ${lib:0:1} == "/"
	then
		. $lib
	else
		local path=($(echo $PATH | awk -F ':' '{for(i=1;i<=NF;i++){print $i}}'))
		local i
		for i in ${path[@]}
		do
			if test -f "$i/$lib"
			then
				. "$i/$lib"
			fi
		done
	fi
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
			test $DEBUG -eq 1 && echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $(time_date) $@" >&2;;
		*)
			echo -e "[${log_str[$log_level]}] $(caller 0 | awk '{print $1}') $(time_date) $@" >&2;;
	esac
}
