#######[ UNDEPLYOMENT OF SWIFT-OBJECT STORAG ESERVICE ]##########
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_controller(){

	echo -e "\n\e[36m####### [ CONTROLLER ] :  UNDEPLOY SWIFT ###### \e[0m\n"
	source ./demo-openrc
	echo "..Delete The File from The container..."
	echo "openstack object delete container1 test_file.txt"
	openstack object delete container1 test_file.txt
	rm -rf /test
	###Source the admin credentials
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "Delete swift service"
	if openstack service list | grep swift;then
        	openstack service delete glance
	fi
	
	echo "Delete user swift"
	if openstack user list | grep swift;then
		openstack user delete swift
	fi
	
	##Unconfig Proxy.conf
	echo "Unconfig Proxy.conf file...."
	cp /etc/swift/proxy-server.conf.bakup /etc/swift/proxy-server.conf

}

unconfig_storage(){
	echo -e "\n\e[36m####### [ OBJECT ] :  UNDEPLOY SWIFT ###### \e[0m\n"
	echo "${object_node[@]}"
	echo "$OBJECT_DISK1"
	echo "$OBJECT_DISK2"
	
	for i in "${object_node[@]}"
	do
		echo -e "\n\e[36m#### [ SWIFT_ON_OBJECT: ] :  DEPLOY SWIFT ON OBJECT NODE ###### \e[0m\n"
		echo "[ object_node $i ]"
		disk1_formated=$(ssh root@$i fsck -N /dev/$OBJECT_DISK1 | grep xfs)
		echo "$disk1_formated"
		disk2_formated=$(ssh root@$i fsck -N /dev/$OBJECT_DISK2 | grep xfs)
		echo "$disk2_formated"
		
	done
	
	#configuration of OBJECT Storage node

	for i in "${object_node[@]}"
	do
		echo "[ object_node $i ]"
		sleep 2
		ssh root@$i  << COMMANDS

		echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m FORMATING DISK'S WITH XFS AND MOUNTING ON OBJECT NODE"
		echo "DISK1: $OBJECT_DISK1"
		echo "DISK2: $OBJECT_DISK2"
		
		if [ -d "/srv/node/$OBJECT_DISK2" ];then
			echo "First Unmount The DISK..."
			umount /dev/$OBJECT_DISK1
			ls -lh /dev/$OBJECT_DISK1
			umount /dev/$OBJECT_DISK2
			ls -lh /dev/$OBJECT_DISK2
			echo "Remove Unmount DISK..."
			rm -rf /srv/node/$OBJECT_DISK1
			rm -rf /srv/node/$OBJECT_DISK2
		fi

		if [ ! -z "$disk1_formated" ];then
			echo "mkfs.ext4  /dev/$OBJECT_DISK1 > /dev/null"
			mkfs.ext4  /dev/$OBJECT_DISK1 > /dev/null
		fi
		
		if [ ! -z "$disk2_formated" ];then
			echo "mkfs.ext4  /dev/$OBJECT_DISK2 > /dev/null"
			mkfs.ext4  /dev/$OBJECT_DISK2 > /dev/null
		fi

                       		
		##Remove Entry From fstab for permanant Unmount
		echo "Remove entry from fstab"
		cp /etc/fstab.bakup /etc/fstab
		
		##Remove rsyncd.conf
		echo "rm -rf /etc/rsyncd.conf"
		rm -rf /etc/rsyncd.conf
		
		##Unconfig rsync
		cp /etc/default/rsync.bakup /etc/default/rsync
		
		##Remove swif-account swift-object, swift container
		echo "..Unconfig /etc/swift/account-server.conf"
		cp /etc/swift/account-server.conf.bak /etc/swift/account-server.conf
		
		echo "..Unconfig /etc/swift/container-server.conf"
		cp /etc/swift/container-server.conf.bak /etc/swift/container-server.conf
		
		echo " /etc/swift/object-server.conf"
		cp /etc/swift/object-server.conf.bak /etc/swift/object-server.conf
			
		##Remove /var/cache/swift directory
		rm -rf /var/cache/swift
COMMANDS
	
	echo -e "\n\e[36m### [ SWIFT_ON_OBJECT: $i ] :  SUCESSFULLY UNDEPLOYED SWIFT ON OBJECT NODE ### \e[0m\n"
	done
}

remove_ring(){
	
	echo -e "\n\e[36m#### [ CONTROLLER ] : REMOVE RING CONFIGURATION AND UNDEPLOY SWIFT ##### \e[0m\n"
	
	##Remove ring file from Object Nodes
	for i in "${object_node[@]}"
	do 
		echo "$i"
		ssh root@$i rm -rf /etc/swift/*.ring.gz
	done
	
	##Remove swift.conf file from Object Nodes
	for i in "${object_node[@]}"
	do 
		echo "$i"
		ssh root@$i rm -rf /etc/swift/swift.conf
	done
	
	ls -l /etc/swift
	
	##Unconfig /etc/swift/swift.conf on CONTROLLER
	echo "Unconfig swift.conf on controller Node"
	cp /etc/swift/swift.conf.bakup /etc/swift/swift.conf
	
	##Restart Services
	echo "Restart memcached and swift-proxy on CONTROLLER"
	service memcached restart
	service swift-proxy restart
	sleep 5
	
	echo "REstart swift-init on both the Object Nodes...."
	ssh root@$OBJECT1_MGT_IP swift-init all start
	ssh root@$OBJECT2_MGT_IP swift-init all start

	
	echo -e "\n\e[36m#### [ SWIFT ] : REMOVEED RING CONFIGURATION AND UNDEPLOYED SERVICE FROM ALL THE NODES #### \e[0m\n"

}
#unconfig_controller
#unconfig_storage
remove_ring