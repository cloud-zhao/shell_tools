drop database if exists my_test_db_name;
create database my_test_db_name default character set utf8;


use my_test_db_name;


#select hosts.host_name,hosts.host_user,hosts.timestamp,hosts_ip.host_ip
#from hosts,hosts_ip,hosts_role 
#where hosts.host_id=hosts_ip.host_id and hosts.host_id=hosts_role.host_id and hosts_role.host_role="MYSQL";
#



#主机表
drop table if exists hosts;
create table hosts (
	host_id		int(6) not null auto_increment,
	host_name	varchar(255) not null,
	host_user	varchar(255) not null,
	password	varchar(255) ,
	timestamp	varchar(20) not null,
	primary key (host_id)
);
#insert into hosts (host_name,host_user,timestamp) values
#("hostname","root","1234567890");

#主机ip表
drop table if exists hosts_ip;
create table hosts_ip (
	host_id		int(6) not null,
	host_ip		varchar(16) not null,
	primary key (host_ip)
);

#主机角色表
drop table if exists hosts_role;
create table hosts_role (
	host_id		int(6) not null,
	host_role	varchar(255) not null
);
