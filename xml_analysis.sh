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


function array_create(){
	local xml_file=$1
	local myxml='.xml_file.xml'
	[ $# -ne 1 ] && return

	cat $xml_file | sed '/^$/d' >$myxml

	xml_head='<?xml version=.*encoding=.*?>'

	sed -i "/$xml_head/d" $myxml
	sed -i '/.*\/>/d' $myxml
	sed -i 's/\s*//g' $myxml

	local xml=$(cat $myxml | tr -d '\n' | awk -F '' '{count=0;
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

	rm -rf $myxml
	echo ${xml[@]}
}


function like_tree(){
	[ $# -lt 2 ] && return
	local myxml=$1 ; shift
	local xml=($@)
	xml=(`shrink ${xml[@]}`)

	local length=${#xml[@]}
	local pi
	for ((pi=1;pi<$length;pi++))
	do
		let pi=$pi-1
		if [ `regex "${xml[$pi]}" "/^<[^\/]*$/"` -eq 1 ]
		then
			local estr=${xml[$pi]}
			let pi=$pi+1
			local pj
			for ((pj=$pi;pj<$length;pj++))
			do
				if [ `regex "${xml[$pj]}" "/^<[^\/]*$/"` -eq 1 ]
				then
					estr="$estr->${xml[$pj]}"
				else
					estr="$estr:${xml[$pj]}"
					echo $estr >>$myxml
					unset xml[$pj]
					local pt=2
					local pk
					for ((pk=$pj+1;pk<=$length;pk++))
					do	
						if [ `regex "${xml[$pk]}" "/^<\/.*$/"` -eq 1 ]
						then
							let local pg=$pk-$pt
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
}

tree_file=".xml_tree.txt"

function xml_new(){
	local xml_file=$1
	local xml=(`array_create $xml_file`)
	like_tree $tree_file ${xml[@]}
}

#function xmlfind(){}
#xmlfind host->name->value return testhost

function xml_find(){
	local xpath=$1 ; shift
	local set_array=($@)

	let local pi=$#%2
	[ $# -gt 0 ] && [ $pi -eq 1 ] && return

	xpath=(`echo $xpath | awk -F '->' '{for(i=1;i<=NF;i++){print $i}}'`)
	xpath=(`shrink ${xpath[@]}`)
	local str_xpath="<${xpath[0]}>"
	unset xpath[0]
	xpath=(`shrink ${xpath[@]}`)
	for i in ${xpath[@]}
	do
		str_xpath="$str_xpath-><$i>"
	done

	if [ ! -f $tree_file ]
	then
		echo "Please use function xml_new create xml tree"
		return
	fi

	grep -i "$str_xpath" $tree_file

}

function xml_end(){
	rm -rf $tree_file
}
