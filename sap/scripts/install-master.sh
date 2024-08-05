#!/bin/bash 
# ------------------------------------------------------------------
# 
#          Install SAP HANA Master Node
#		   Run once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() { 
	cat <<EOF
	Usage: $0 [options]
		-h print usage
		-s SID
		-i instance
		-p HANA password
		-n MASTER_HOSTNAME
		-d DOMAIN
		-l HANA_LOG_FILE [optional]
EOF
	exit 1
}

[ -e /root/install/jq ] && export JQ_COMMAND=/root/install/jq
[ -z ${JQ_COMMAND} ] && export JQ_COMMAND=/home/ec2-user/jq
export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin
myInstance=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document/ | ${JQ_COMMAND} '.instanceType' | \
			 sed 's/"//g')


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


while getopts ":h:s:i:p:n:d:l:" o; do
    case "${o}" in
        h) usage && exit 0
			;;
		s) SID=${OPTARG}
			;;
		i) INSTANCE=${OPTARG}
			;;
		p) HANAPASSWORD=${OPTARG}
			;;
		n) MASTER_HOSTNAME=${OPTARG}
			;;
		d) DOMAIN=${OPTARG}
			;;
                l) HANA_LOG_FILE=${OPTARG}
                        ;;
        *)
            usage
            ;;
    esac
done

# ------------------------------------------------------------------
#          Helper functions
#          log()
#          update_status()
#          create_volume()
#          set_noop_scheduler()
# ------------------------------------------------------------------

log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

update_status () {
   local status="$1"
   if [ "$status" ]; then
      if [ -e /root/install/cluster-watch-engine.sh ]; then
         sh /root/install/cluster-watch-engine.sh -s "$status"
      fi
   fi
}

create_volume () {
	log "Creating Physical Volumes for saphana volume group"
	#for i in {b..m}
	for i in {b..e}
	do
	  pvcreate /dev/xvd$i 
	done	
}


set_noop_scheduler () {
	log "Setting i/o scheduler to noop for each physical volume" 
	for i in `pvs | grep dev | awk '{print $1}' | sed s/\\\/dev\\\///`
	do
	  echo "noop" > /sys/block/$i/queue/scheduler
	  printf "$i: " 
	  cat /sys/block/$i/queue/scheduler 
	done

}


# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------


[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$INSTANCE" ]]  && echo "input INSTANCE missing" && usage;
[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MASTER_HOSTNAME missing" && usage;

shift $((OPTIND-1))

[[ $# -gt 0 ]] && usage;

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
	HANA_LOG_FILE=/root/install/install.log
fi


echo `date` BEGIN install-master  2>&1 | tee -a ${HANA_LOG_FILE}


#HANAEXTHOST=`curl http://169.254.169.254/latest/meta-data/public-hostname/`

update_status "CONFIGURING_INSTANCE_FOR_HANA"
create_volume;
set_noop_scheduler;


logsize=",c3.8xlarge:60G,r3.2xlarge:60G,r3.4xlarge:122G,r3.8xlarge:244G,"
datasize=",c3.8xlarge:180G,r3.2xlarge:180G,r3.4xlarge:366G,r3.8xlarge:732G,"
sharedsize=",c3.8xlarge:60G,r3.2xlarge:60G,r3.4xlarge:122G,r3.8xlarge:244G,"
backupsize=",c3.8xlarge:300G,r3.2xlarge:300G,r3.4xlarge:610G,r3.8xlarge:1200G,"


get_logsize() {
    echo "$(expr "$logsize" : ".*,$1:\([^,]*\),.*")"
}

get_datasize() {
    echo "$(expr "$datasize" : ".*,$1:\([^,]*\),.*")"
}
get_sharedsize() {
    echo "$(expr "$sharedsize" : ".*,$1:\([^,]*\),.*")"
}
get_backupsize() {
    echo "$(expr "$backupsize" : ".*,$1:\([^,]*\),.*")"
}

mylogSize=$(get_logsize  ${myInstance})
mydataSize=$(get_datasize   ${myInstance})
mysharedSize=$(get_sharedsize  ${myInstance})
mybackupSize=$(get_backupsize  ${myInstance})

# ------------------------------------------------------------------
#          Create volume group vghana
#          Create Logical Volumes
#          Format filesystems
# ------------------------------------------------------------------

log "Creating volume group vghana"
#vgcreate vghana /dev/xvd{b..m}
vgcreate vghana /dev/xvd{b..e}
log "Creating hana shared logical volume"
lvcreate -n lvhanashared -i 4 -I 256 -L ${mysharedSize}  vghana
log "Creating hana data logical volume" 
lvcreate -n lvhanadata -i 4 -I 256  -L ${mydataSize} vghana
log "Creating hana log logical volume" 
lvcreate -n lvhanalog  -i 4 -I 256 -L ${mylogSize} vghana
log "Creating backup logical volume" 
lvcreate -n lvhanaback  -i 4 -I 256  -L ${mybackupSize} vghana

log "Formatting block device for /usr/sap" 
mkfs.xfs -f /dev/xvds 		


#/backup /hana/shared /hana/log /hana/data

for lv in `ls /dev/mapper | grep vghana`
do
   log "Formatting logical volume $lv"
   mkfs.xfs /dev/mapper/$lv
done

# ------------------------------------------------------------------
#          Create mount points and important directories
#		   Update /etc/fstab
#		   Mount all filesystems
# ------------------------------------------------------------------


log "Creating SAP and HANA directories"
mkdir /usr/sap

mkdir /hana /hana/log /hana/data /hana/shared 
mkdir /backup

log "Creating mount points in fstab"
echo "/dev/xvds			  /usr/sap       xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanashared   /hana/shared   xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanadata     /hana/data     xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanalog      /hana/log      xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab 
echo "/dev/mapper/vghana-lvhanaback     /backup        xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/xvdz1                        /media         ntfs rw,allow_other 0 0" >> /etc/fstab

log "mounting filesystems"
mount -a
mount


# ------------------------------------------------------------------
#          Creating additional directories
#          Activate LVM @boot
# ------------------------------------------------------------------

mkdir /hana/data/$SID /hana/log/$SID
mkdir /usr/sap/$SID
mkdir /backup/data /backup/log /backup/data/$SID /backup/log/$SID

log "Turning on Activate of LVM at boot"
chkconfig boot.lvm on

# ------------------------------------------------------------------
#          Install HANA Master
# ------------------------------------------------------------------
update_status "INSTALLING_SAP_HANA"
sh ${SCRIPT_DIR}/install-hana-master.sh -p $HANAPASSWORD -s $SID -i $INSTANCE -n $MASTER_HOSTNAME -d $DOMAIN
update_status "PERFORMING_POST_INSTALL_STEPS"

##ensure nfs service starts on boot
log "Installing and configuring NFS Server"
zypper --non-interactive install nfs-kernel-server

sed -i '/STATD_PORT=/ c\STATD_PORT="4000"' /etc/sysconfig/nfs
sed -i '/LOCKD_TCPPORT=/ c\LOCKD_TCPPORT="4001"' /etc/sysconfig/nfs
sed -i '/LOCKD_UDPPORT=/ c\LOCKD_UDPPORT="4001"' /etc/sysconfig/nfs
sed -i '/MOUNTD_PORT=/ c\MOUNTD_PORT="4002"' /etc/sysconfig/nfs

service nfsserver start
chkconfig nfsserver on

##configure NFS exports
echo "#Share global HANA shares" >> /etc/exports
echo "/hana/shared   imdbworker*(rw,no_root_squash,no_subtree_check)" >> /etc/exports
echo "/backup        imdbworker*(rw,no_root_squash,no_subtree_check)" >> /etc/exports
exportfs -a

log "Current exports"
showmount -e

log `date` END install-master 

cat ${HANA_LOG_FILE} >> /var/log/messages

exit 0
