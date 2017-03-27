#!/bin/bash

RED='\033[0;31m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
GRE='\033[0;32m'
NC='\033[0m'

namenode=`hostname`
echo -en "Check Services on NameNode ${YEL}($namenode)${NC} .. "
dlist=`jps`
error=0
errmsg=""
echo -e $dlist | grep "NameNode" >/dev/null
if [[ $? -ne 0 ]]; then
	error=1
	errmsg="$errmsg NameNode,"
fi
echo -e $dlist | grep "ResourceManager" >/dev/null
if [[ $? -ne 0 ]]; then
	error=1
	errmsg="$errmsg ResourceManager,"
fi
echo -e $dlist | grep "JobHistoryServer" >/dev/null
if [[ $? -ne 0 ]]; then
	error=1
	errmsg="$errmsg JobHistoryServer,"
fi
echo -e $dlist | grep "HistoryServer"  >/dev/null
if [[ $? -ne 0 ]]; then
	error=1
	errmsg="$errmsg HistoryServer,"
fi

if [[ $error == 1 ]]; then
	echo -e  "${RED}NOT OK ${NC}"
	echo -e "${CYAN}$errmsg${NC}  not active in $namenode"
else
	echo -e "${GRE}OK${NC}"
fi

error=0
errmsg=""
for userhost in `cat ${HADOOP_HOME}/etc/hadoop/slaves | grep -v ^#`
do
	echo -en "Check Services on DataNode ${YEL}($userhost)${NC} .. "
	dlist=`ssh $userhost jps `

	echo -e $dlist | grep "DataNode" >/dev/null
	if [[ $? -ne 0 ]]; then
		error=1
		errmsg="$errmsg DataNode,"
	fi

	echo -e $dlist | grep "NodeManager" >/dev/null
	if [[ $? -ne 0 ]]; then
		error=1
		errmsg="$errmsg NodeManager,"
	fi
	if [[ $error == 1 ]]; then
		echo -e  "${RED}NOT OK ${NC}"
		echo -e "${CYAN}$errmsg${NC} not active in $userhost"
	else
		echo -e "${GRE}OK${NC}"
	fi
done