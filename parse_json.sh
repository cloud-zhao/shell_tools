#!/bin/bash

if [ "$BASH_PARSE_JSON" ];then
	return
fi
export BASH_PARSE_JSON=1

abs_path=$(cd $(dirname $0);pwd)
parse_json="$abs_path/.parse_json.txt"

function _p_json(){
	local json_file=$1
	local p_json_file=$2

	cat $json_file | awk -F '' '
	function get_str(str){
		str="";
		i+=1;
		for(;i<=NF;i++){
			if($i=="\""){
				i++;
				if(str==""){
					return "NULL";
				}else{
					return str;
				}
			}
			str=str""$i;
		}	
	}

	function get_bool(){
		if($i=="f"){
			i=i+4;
			return "false";
		}else if($i=="t"){
			i=i+3;
			return "true";
		}
	}

	function get_int(str_int){
		str_int=""
		for(;i<=NF;i++){
			if($i==","||$i=="}"||$i=="]"){
				i--;
				return str_int;	
			}
			str_int=str_int""$i;
		}
	}

	function parse_object(obj_key,obj_str,tmp_key,oj,oi){
		i+=1;
		if(tmp_key){
			obj_key=tmp_key
		}
		for(;i<=NF;i++){
			if($i=="\""){
				obj_str=get_str();
				if($i==":"){
					if(!oi){
						tmp_key=obj_key"_"obj_str;
					}else{
						tmp_key=obj_key"_"obj_str"_"oj;
					}
					i--;
				}else if($i==","||$i=="]"){
					json[tmp_key]=obj_str;
					#print "OBJECT: "tmp_key"\t"obj_str;
				}else if($i=="}"){
					json[tmp_key]=obj_str;
					#print "OBJECT: "tmp_key"\t"obj_str;
					i--;
				}
			}else if($i=="{"){
				parse_object(obj_key,"",tmp_key);
			}else if($i=="}"){
				return;
			}else if($i=="["){
				parse_array(obj_key,"",tmp_key);
			}else if($i==":"){
				i++
				if($i~/[0-9]/){
					obj_str=get_int();
					json[tmp_key]=obj_str;
					#print "INT: "tmp_key"\t"obj_str"\n";
				}else if($i~/[tf]/){
					obj_str=get_bool();
					json[tmp_key]=obj_str;
				}else{
					i--;
				}
			}
		}
	}

	function parse_array(array_key,array_str,tmp_key,aj){
		i+=1;
		aj=0;
		if(tmp_key){
			array_key=tmp_key;
		}
		for(;i<=NF;i++){
			if($i=="\""){
				array_str=get_str();
				if($i==":"){
					tmp_key=array_key"_"array_str;
					i--;
				}else if($i==","||$i=="}"){
					json[tmp_key]=array_str","json[tmp_key];
				}else if($i=="]"){
					json[tmp_key]=array_str","json[tmp_key];
					i--;
				}
			}else if($i=="{"){
				parse_object(array_key,"",tmp_key,aj,1);
				aj++;
			}else if($i=="]"){
				return;
			}else if($i=="["){
				parse_array(array_key,"",tmp_key);
			}else if($i==":"){
				i++;
				if($i~/[0-9]/){
					array_str=get_int();
					json[tmp_key]=array_str;
				}else if($i~/[tf]/){
					array_str=get_bool();
					json[tmp_key]=array_str;
				}else{
					i--;
				}
			}
		}
	}

	{for(i=1;i<=NF;i++){
		if($i=="{"){
			parse_object("root","");
		}else{
			print "JSON format error.\t"$i"\n";
			exit
		}
	}}

	END{
		for(k in json){
			print k"\t"json[k];
		}	
	}' >$p_json_file

}

function decode_json{
	local json_str=$1;
	_p_json $json_file $parse_json
}

#root->load->[1]
function get_value{
	local path=$1;
	path=$(echo $path | awk -F '->' '{str="root";for(i=1;i<=NF;i++){str=str"_"$i};print str}')
	path=$(echo $path | sed 's/\[\|\]//g')
	grep "$path" $parse_json
}

function destroy{
	rm -rf $parse_json;
}


