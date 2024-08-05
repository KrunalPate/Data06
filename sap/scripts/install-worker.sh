#!/bin/bash 


# ------------------------------------------------------------------
# 
#          Install SAP HANA Worker Node
#		   Run once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() { 
	cat <<EOF
	Usage: $0 [options]
		-h print usage
		-s SID
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


while getopts ":h:s:p:n:d:l:" o; do
    case "${o}" in
        h) usage && exit 0
			;;
		s) SID=${OPTARG}
			;;
		p) HANAPASSWORD=${OPTARG}
			;;
		n) MASTER_HOSTNAME=${OPTARG}
			;;
		d) DOMAIN=${OPTARG}
			;;
        l)
           HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done


# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------


[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MASTER_HOSTNAME missing" && usage;
[[ -z "$DOMAIN" ]]  && echo "input DOMAIN Name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;


# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi


log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


log `date` BEGIN install-worker

update_status () {
   local status="$1"
   if [ "$status" ]; then
      if [ -e /root/install/cluster-watch-engine.sh ]; then
         sh /root/install/cluster-watch-engine.sh -s "$status"
      fi
   fi
}

update_status "CONFIGURING_INSTANCE_FOR_HANA"

# ------------------------------------------------------------------
#          Create PV's for LVM2 saphana volume group
# ------------------------------------------------------------------

log "Creating Physical Volumes for saphana volume group"
for i in {b..e}
do
  pvcreate /dev/xvd$i 
done


# ------------------------------------------------------------------
#           Set i/o scheduler to noop
# ------------------------------------------------------------------

log "Setting i/o scheduler to noop for each physical volume"
for i in `pvs | grep dev | awk '{print $1}' | sed s/\\\/dev\\\///`
do
  echo "noop" > /sys/block/$i/queue/scheduler
  printf "$i: " 
  cat /sys/block/$i/queue/scheduler 
done


# ------------------------------------------------------------------
#          Create volume group vghana
#          Create Logical Volumes
#          Format filesystems
# ------------------------------------------------------------------

log "Creating volume group vghana"
vgcreate vghana /dev/xvd{b..e}


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



log "Creating hana data logical volume"
lvcreate -n lvhanadata -i 4  -I 256 -L ${mydataSize} vghana
log "Creating hana log logical volume"
lvcreate -n lvhanalog  -i 4 -I 256  -L ${mylogSize} vghana

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
echo "/dev/xvds			   /usr/sap       xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanadata     /hana/data     xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanalog      /hana/log      xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab 

log "mounting filesystems"
mount -a
mount

mkdir /hana/data/$SID /hana/log/$SID
#mkdir /usr/sap/$SID

##activate LVM at boot
log "Turning on Activate of LVM at boot"
chkconfig boot.lvm on

##configure autofs
log  "Configuring NFS client services"
sed -i '/auto.master/c\#+auto.master' /etc/auto.master
echo "/- auto.direct" >> /etc/auto.master
echo "/hana/shared	-rw,rsize=32768,wsize=32768,timeo=14,intr     $MASTER_HOSTNAME.$DOMAIN:/hana/shared" >> /etc/auto.direct
echo "/backup		-rw,rsize=32768,wsize=32768,timeo=14,intr     $MASTER_HOSTNAME.$DOMAIN:/backup" >> /etc/auto.direct

#trigger automount to mount shared filesystems
echo "trigger automount to mount shared filesystems"
ls -l /hana/shared
ls -l /backup

##Install HANA

#Change permissions temporarily for install
chmod 777 /hana/data/$SID /hana/log/$SID

update_status "INSTALLING_SAP_HANA"
sh ${SCRIPT_DIR}/install-hana-worker.sh -p $HANAPASSWORD -s $SID -n $MASTER_HOSTNAME -d $DOMAIN
update_status "PERFORMING_POST_INSTALL_STEPS"

#Fix permissions
chmod 755 /hana/data/$SID /hana/log/$SID

echo `date` END install-worker  >> /root/install/install.log

cat /root/install/install.log >> /var/log/messages
