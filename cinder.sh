##############[ DEPLOYING BLOCK STORAGE SERVICE ON CONTROLLER AND BLOCK1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh
source /root/autovm/chk_Connectivity.sh

Cinder_installation_pre(){

echo -e "\n\n\e[36m#########[ DEPLOYING CINDER PART ON CONTROLLER NODE ]######### \e[0m\n"
	
	echo -e "\n\e[36m[CONFIGURATION THE MYSQL DB ] \e[0m\n"
	
mysql << EOF
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$COMMON_PASS';
EOF

	sleep 5
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
	sleep 2

	echo "---Create Cinder user-----"
	echo "openstack user create --domain default --password $COMMON_PASS cinder"
	openstack user create --domain default --password $COMMON_PASS cinder

	echo "--Adding Admin Role to the Cinder User----"
	echo "openstack role add --project service --user cinder admin"
	openstack role add --project service --user cinder admin
	
	echo "--Create Cinderv2 and Cinderv3 Service Entities----"
	echo " openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2"
	openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	
	echo "openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3"
	openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
	
	#####API ENDPOINTS FOR VOLUMEV2#####
	echo "----Create Block Storage API EndPoints For Volumev2----"
	echo "openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
	
	echo "openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
	
	echo "openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
	
	
	######API ENDPOINTS FOR VOLUMEV3#####
	echo "----Create Block Storage API EndPoints For Volumev3----"
	echo "openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
	
	
	echo "openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s

	echo "openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s"
	openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s
	
	sleep 5
}

cinder_config_controller(){
###installing Packages on Controller Node####

PKG_FAILED=0
	apt install cinder-api cinder-scheduler -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20
	
	filepath1='/etc/cinder/cinder.conf'
	# Backup the original .conf file
	
	cp $filepath1 ${filepath1}.bak
	
	echo "---STARTED CONFIGURATION-----"

	sed -i '/^state_path =*/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\nmy_ip = '$CONTROLLER_MGT_IP'\nauth_strategy = keystone' $filepath1
	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[database\]/ a connection = mysql+pymysql://cinder:'$COMMON_PASS'@controller/cinder' $filepath1
	
	grep -q "^www_authenticate_uri = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = cinder\npassword = '$COMMON_PASS'' $filepath1
	
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/neutron/tmp' $filepath1
	
	sleep 2
	
	echo "----Populate The Database-----"
	echo "su -s /bin/sh -c "cinder-manage db sync" cinder"
	su -s /bin/sh -c "cinder-manage db sync" cinder
	sleep 2
	
	echo "---Configue Compute to Use Block Storage---"
	sed -i '/^\[cinder\]/ a os_region_name = RegionOne' /etc/nova/nova.conf
	
	#### RESTART THE NOVA_API AND BLOCK STORAG SERVICES ##############
	
	echo "service nova-api restart"
	service nova-api restart
	sleep 2
	
	echo "service cinder-scheduler restart"
	service cinder-scheduler restart
	sleep 2
	
	echo "service apache2 restart"
	service apache2 restart
	sleep 2

}

config_block1(){

echo "---Configuration of Block Storage Service on Block1 Node Started......."
##### Installing Packages####
	PKG_FAILED=0
	ssh root@$BLOCK1_MGT_IP apt install lvm2 thin-provisioning-tools cinder-volume -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n---PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 15
<<'COMMENTS'
	filepath1='/etc/cinder/cinder.conf'
	filepath2 ='/etc/lvm/lvm.conf'
	# Backup the original .conf file
	
	#Remote configuration of BLOCK Storage node.
	#ssh -T -t root@$BLOCK1_MGT_IP << COMMANDS
	
	cp $filepath1 ${filepath1}.bak
	cp $filepath2 ${filepath2}.bak
	
	if [ -z "$vg_exist" ];then
			pvcreate /dev/$BLOCK1_LVM_DISKNAME
			vgcreate cinder-volumes /dev/$BLOCK1_LVM_DISKNAME
		else
			echo -e "\n\e[36m[ CINDER_ON_BLOCK ] :\e[0m Cinder-Volume Already Exist not creating"
		fi
		
		sed -i 's/filter = \[ \"a\/\.\*\/\" \]/filter = \[ \"a\/'$BLOCK1_LVM_DISKNAME'\/\", \"r\/\.\*\/\"\]/' $file
		#sed -i's/filter = \[ \"\a\/'$BLOCK1_LVM_DISKNAME'\/\", \"r\/\.\*\/\"\]/filter = \[ \"a\/\.\*\/\" \]/' $file
	
	
	echo -e "\n\e[36m[ CINDER_ON_BLOCK ] :\e[0m Configure cinder configuration file"

	        grep -q "^\[database\]" $filepath1 || \
        	sed -i '$ a [database]\nconnection = mysql+pymysql://cinder:'$DB_PASS'@controller/cinder' $filepath1

        	sed -i '/^\[DEFAULT\]/ a rpc_backend = rabbit\nmy_ip = '$BLOCK1_MGT_IP'\nenabled_backends = lvm\nglance_api_servers = http:\/\/controller:9292' $filepath1
		
		`declare -f config_keystone_authtoken`
        	config_keystone_authtoken $file1 "cinder" $COMMON_PASS
		`declare -f config_oslo_messaging_rabbit`
        	config_oslo_messaging_rabbit $file1 $COMMON_PASS

        	grep -q "^\[oslo_concurrency\]" $file1 || sed -i '$ a [oslo_concurrency]\nlock_path = /var/lib/cinder/tmp' $filepath1

		grep -q "^\[lvm\]" $file1 || \
		sed -i '$ a [lvm]\nvolume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver\nvolume_group = cinder-volumes\niscsi_protocol = iscsi\niscsi_helper = tgtadm' $filepath1
		
		echo -e "\n\e[36m[ CINDER_ON_BLOCK ] :\e[0m Restart the Block Storage volume service"

		service tgt restart
		service cinder-volume restart
		COMMANDS
COMMENTS
}

Cinder_installation_pre
#cinder_config_controller
#config_block1