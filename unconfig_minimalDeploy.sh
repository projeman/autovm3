############[ UnConfiguration Of The OpenStack Deployment ]#####################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_hostname(){

###Copy the backup file with the existing
##On Controller Node

	echo "cp /etc/hosts.bak /etc/hosts"
	cp /etc/hosts.bak /etc/hosts

###ON the Other Nodes

	echo "${nodes}"
	for i in "${nodes[@]}"
		do 
			echo "$i"
			scp /etc/hosts root@$i:/etc/
		done
		
	echo -e "\nREMOVING THE HOSTNAME FROM ALL NODES IS DONE...\e[0m \n"	

}

unconfig_Ntp(){
	echo "--Copy the backup file--"
	cp /etc/chrony/chrony.conf.bak /etc/chrony/chrony.conf
	
	echo -e "\n\e[36m######################## NTP UNCONFIGURATION ON ALL NODES IN PROCESS ####################### \e[0m\n"
	
	for i in "${nodes[@]}"
    do
		echo "$i"
		scp /etc/chrony/chrony.conf root@$i:/etc/chrony/chrony.conf 
    done
	
	echo -e "\n\n\e[36m######################## NTP UNCONFIGURATION ON ALL NODES IN DONE ################################# \e[0m\n"

}

unconfig_Mysql(){

	echo -e "\n\n\e[36m###### MYSQL UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE ###### \e[0m\n"	
	service mysql stop
	rm -rf /etc/mysql/mariadb.conf.d/99-openstack.cnf
	service mysql start

	echo -e "\n\n\e[36m######MYSQL UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE IN DONE #### \e[0m\n"

}

unconfig_Rabbitmq(){

	echo -e "\n\n\e[36m## MESSAGE QUEUE (RABBITMQ) UNINSTALL ON CONTROLLER NODE ##### \e[0m\n"

	rabbitmqctl stop_app
	rabbitmqctl reset
	rabbitmqctl start_app
	
	echo -e "\n\n\e[36m#### MESSAGE QUEUE (RABBITMQ) UNINSTALL ON CONTROLLER NODE IN DONE ####\e[0m\n"

}

unconfig_Memcached(){

        echo -e "\n\n\e[36m#### MEMCACHED INSTALL AND CONFIGURE ON CONTROLLER NODE ###### \e[0m\n"

        sed -i 's/^-l '$CONTROLLER_MGT_IP'/-l 127.0.0.1/' /etc/memcached.conf
        service memcached restart

        echo -e "\n\n\e[36m### MEMCACHED UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE IS DONE ##### \e[0m\n"

}

drop_database(){

        drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep $1$)
        if [ ! -z "$drpdb" ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE $1;DROP USER '$1'@'localhost';DROP USER '$1'@'%';"
        fi

}

unconfig_etcd(){

	echo "--Reset The original File Using BackUp File---"
	cp /etc/default/etcd.bak /etc/default/etcd

	echo -e "\n\n\e[36m### ETCD UNINSTALL ON CONTROLLER NODE IS DONE ##### \e[0m\n"
}

######################[ UNCONFIG OPENSTACK SERVICES ]##################

unsetting-openrc(){
	
		unset OS_PROJECT_DOMAIN_NAME
        unset OS_USER_DOMAIN_NAME
        unset OS_PROJECT_NAME
        unset OS_USERNAME
        unset OS_PASSWORD
        unset OS_AUTH_URL
        unset OS_IDENTITY_API_VERSION
        unset OS_IMAGE_API_VERSION

}

unconfig_Identity(){
	
	echo -e "\n\n\n\e[36m######################[ KEYSTONE ] : UNDEPLOY IDENTITY SERVICE  #####################\e[0m\n\n\n"
	file="/etc/keystone/keystone.conf"
	
	#Create Keystone Service
        source ./admin-openrc
		
	if openstack service list | grep keystone;then
        	openstack service delete keystone
	fi
        #remove env variables
        unsetting-openrc
	if [ -f ".admin-openrc" ];then
		rm ./admin-openrc
	fi
	if [ -f ".demo-openrc" ];then
                rm ./demo-openrc
        fi	

	echo -e "\n\e[36m[ KEYSTONE ] :\e[0m Droping the MYSQL DB.."
	# DROP Mysql datatbse for keystone
	chkdb=$(mysql -uroot -p$DB_PASS -e "SHOW DATABASES;" | grep "keystone")
	if [ ! -z "$chkdb" ];
	then
		mysql -u root -p$DB_PASS -e "DROP DATABASE keystone;DROP USER 'keystone'@'localhost';DROP USER 'keystone'@'%';"
	fi
       	
	echo -e "\n\e[36m[ KEYSTONE ] :\e[0m Removing the config parameter"
	# Remove Config parameter
	cp /etc/keystone/keystone.conf.bak /etc/keystone/keystone.conf
	
	cp /etc/apache2/apache2.conf.bak /etc/apache2/apache2.conf
	
	service apache2 stop
	
}



unconfig_glance(){

	echo -e "\n\n\n\e[36m##### [ GLANCE ] : UNDEPLOYING THE GLANCE SERVICE #####\e[0m\n\n\n"

	echo "rm -rf /var/lib/glance/images/*"
	rm -rf /var/lib/glance/images/*	
	sleep 2
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "Delete glance service"
	if openstack service list | grep glance;then
        	openstack service delete glance
	fi
	
	echo "Delete user glance"
	if openstack user list | grep glance;then
		openstack user delete glance
	fi
	

    # Droping the Glance Mysql database
	echo -e "\n\e[36m[ GLANCE ] : DROPING THE GLANCE DB....\n"

    drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "glance")
        if [ ! -z $drpdb ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE glance;DROP USER 'glance'@'localhost';DROP USER 'glance'@'%';"
        fi
	
	#Remove all configurations of Glance Service
	echo -e "\n[GLANCE] : REMOVING THE CONFIGURATION PARAMETER\n"
	
	# Unconfigure image config of glance-api
	cp /etc/glance/glance-api.conf.bakup /etc/glance/glance-api.conf
	
	# Configuration parameters of glance-regisery
     cp /etc/glance/glance-registry.conf.backup /etc/glance/glance-registry.conf

	if [ -f "cirros-0.4.0-x86_64-disk.img" ]; then
		echo "Deleting cirros image"
		rm -rf cirros-0.4.0-x86_64-disk.img
	fi
	
	echo ""--Remove All the existing Images--"
	rm -rf *.img*
	
	echo "--Restart Service--"
	service glance-registry restart
	service glance-api restart
	echo "Verify Undeployment of glance"
	openstack image list
	echo -e "\n\n\e[36m###[ GLANCE ] : SUCCESSFULLY UNINSTALLED GLACE IMAGE SERVICE ###\e[0m\n\n\n"
	
}

unconfig_placement(){

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
	echo "Delete glance service"
	
	if openstack service list | grep placement;then
        	openstack service delete placement
	fi
	
	echo "Delete user placement"
	if openstack user list | grep placement;then
		openstack user delete placement
	fi
	

    # Droping the Placement Mysql database
	echo -e "\n\e[36m[ PLACEMENT ] : DROPING THE PLACEMENT DB....\n"

    drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "placement")
        if [ ! -z $drpdb ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE placement;DROP USER 'placement'@'localhost';DROP USER 'placement'@'%';"
        fi
	
	#Remove all configurations of Placement Service
	echo -e "\n[PLACEMENT] : REMOVING THE CONFIGURATION PARAMETER\n"
	
	# Unconfigure Placement
	cp /etc/placement/placement.conf.bakup /etc/placement/placement.conf
	
	echo "Restart Services"
	service apache2 restart


}

unconfig_Identity
#unconfig_placement




