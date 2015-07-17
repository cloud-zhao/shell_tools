
function array(){
	local array_name=$1
	local array='echo ${'$array_name'[@]}'
	eval $array
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

	local bin="/root/cloudzhao/install/sendEmail"
	
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
