#!/bin/bash

function shrink(){
	local aa=($@)
	local j
	local p=0
	local bb=()

	for j in ${aa[@]}
	do
		bb[$p]=$j
		let p=$p+1
	done
	echo ${bb[@]}
}

function regex(){
	local str=$1
	local reg=$2

	echo $(echo $str | awk '{if($0 ~ '"$reg"'){print "1"}else{print "0"}}')
}

xml_file=$1
myxml=".xml_file.xml"
cat $xml_file | sed '/^$/d' >$myxml

xml_head='<?xml version=.*encoding=.*?>'

if [ `cat $xml_file | grep "$xml_head" | wc -l` -eq 0 ]
then
	echo "xxxxx"
	exit
fi

sed -i "/$xml_head/d" $myxml
sed -i '/.*\/>/d' $myxml
sed -i 's/\s*//g' $myxml

xml=$(cat $myxml | tr -d '\n' | awk -F '' '{count=0;
	for(i=1;i<=NF;i++){
		if($i=="<"){
			str=$i;i++;
			for(;i<=NF;i++){
				str=str""$i;
				if($i==">"){
					strall[count]=str;
					count++;
					break;
				}
			}		
		}else{
			value_str=$i;i++;
			for(;i<=NF;i++){
				if($i=="<"){
					i--;
					break;
				}
				value_str=value_str""$i;
			}
			strall[count]=value_str;
			count++;
		}
	}
}END{for(pi=0;pi<length(strall);pi++){print strall[pi];}}')

#function xmlfind(){}
#xmlfind host->name->value return testhost

xml=(`shrink $xml`)

length=${#xml[@]}
for ((pi=0;pi<$length;pi++))
do
	if [ `regex "${xml[$pi]}" "/^<[^\/]*$/"` -eq 1 ]
	then
		estr=${xml[$pi]}
		let pi=$pi+1
		for ((pj=$pi;pj<$length;pj++))
		do
			if [ `regex "${xml[$pj]}" "/^<[^\/]*$/"` -eq 1 ]
			then
				estr="$estr->${xml[$pj]}"
			else
				estr="$estr:${xml[$pj]}"
				echo $estr
				unset xml[$pj]
				pt=2
				for ((pk=$pj+1;pk<=$length;pk++))
				do	
					if [ `regex "${xml[$pk]}" "/^<\/.*$/"` -eq 1 ]
					then
						let pg=$pk-$pt
						#echo "unset ${xml[$pg]}"
						#echo "${xml[$pk]}====${xml[$pg]}===$pk--->$pg"
						unset xml[$pk]
						unset xml[$pg]
						let pt=$pt+2
					else
						break;
					fi
				done
				xml=(`shrink ${xml[@]}`)
				length=${#xml[@]}
				pi=0;
				break;
			fi
		done
	fi
done

#for xmlstr in ${xml[@]}
#do
#	echo $xmlstr
#done
