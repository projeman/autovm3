#!/bin/sh
#CONTROLLER VARiABLES
#echo "reached 3" > /root/out3.txt
CONTROLLER_MGT_IP="10.0.0.11"
CONTROLLER_PUB_IP="10.116.32.11"
CONTROLLER_HOSTNAME="controller"

#COMPUTE VARIABLES

COMPUTE1_MGT_IP="10.0.0.31"
COMPUTE1_PUB_IP="10.116.32.12"
COMPUTE1_HOSTNAME="compute1"

#BLOCK1 STORAGE SERVICE
BLOCK1_MGT_IP="10.0.0.41"
BLOCK1_HOSTNAME="block1"
#IF NO PUBLIC IP GIVEN, THEN PROVIDE MAC ID OF UNUSED INETRFACE (dont give mac of mgt_ip interface)
#BLOCK1_PUB_IP="00:26:55:ea:b2:7c"
#BLOCK1_LVM_DISKNAME="sdb"

#GATEWAY NODE
GATEWAY_MGT_IP="10.0.0.1"
GATEWAY_HOSTNAME="gateway"

COMMON_PASS="redhat"
#DB_PASS="redhat"

ADMIN_TOKEN="$(openssl rand -hex 10)"

#ARRAY OF ALL THE AVILABLE NODES, MAKE SURE YOU HAVE ALL HOSTS IN THIS ARRAY, NEW ADDED NODE ENTRY SHOULD EXIST HERE.

declare -a nodes=("$COMPUTE1_MGT_IP" "$BLOCK1_MGT_IP")