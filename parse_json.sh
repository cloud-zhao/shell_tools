#!/bin/bash

abs_path=$(cd $(dirname $0);pwd)
parse_json="$abs_path/.parse_json.txt"

function decode_json{
	local json_str=$1;
	cat $json_file | awk -f $abs_path/parse_json.awk >$parse_json
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
