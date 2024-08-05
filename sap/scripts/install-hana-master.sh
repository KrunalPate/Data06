#!/bin/bash

# ------------------------------------------------------------------
#	   This script installs HANA, configures HANA instance
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
    cat <<EOF
    Usage: $0 [options]
	-h print usage
	-p HANA MASTER PASSWD
	-s HANA SID
	-i HANA Instance Number
	-n HANA Master Hostname
	-d Domain
	-l HANA_LOG_FILE [optional]
EOF
    exit 1
}

# ------------------------------------------------------------------
#	   Read all inputs
# ------------------------------------------------------------------


while getopts ":h:p:s:i:n:d:l:" o; do
    case "${o}" in
	h) usage && exit 0
	    ;;
	p) HANAPASSWORD=${OPTARG}
	    ;;
	s) SID=${OPTARG}
	    ;;
	i) INSTANCE=${OPTARG}
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
#	   Make sure all input parameters are filled
# ------------------------------------------------------------------


[[ -z "$HANAPASSWORD" ]]  && echo "input MASTER PASSWD missing" && usage;
[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$INSTANCE" ]]  && echo "input Instance Number missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input Hostname missing" && usage;
[[ -z "$DOMAIN" ]]  && echo "input Domain name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

# ------------------------------------------------------------------
#	   Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi


# ------------------------------------------------------------------
#	   Pick the right HANA Media!
# ------------------------------------------------------------------

#HANAMEDIA_DIR=/media/51047822
#HANAMEDIA=${HANAMEDIA_DIR}/DATA_UNITS
HANAMEDIA=$(/usr/bin/find /media -type d -name "DATA_UNITS")

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


log `date` BEGIN install-hana-master

# ------------------------------------------------------------------
#	   Generate Install Files
# ------------------------------------------------------------------

#Password File
PASSFILE=${SCRIPT_DIR}/passwords.xml
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $PASSFILE
echo "<Passwords>" >> $PASSFILE
echo "<password>${HANAPASSWORD}</password>" >> $PASSFILE
echo "<sapadm_password>${HANAPASSWORD}</sapadm_password>" >> $PASSFILE
echo "<system_user_password>${HANAPASSWORD}</system_user_password>" >> $PASSFILE
echo "<root_password>${HANAPASSWORD}</root_password>" >> $PASSFILE
echo "</Passwords>" >> $PASSFILE


log '================================================================='
log '========================Installing and configuring HANA=========='
log '================================================================='

#Run Installer
# cat $PASSFILE | $HANAMEDIA/HDB_LCM_LINUX_X86_64/hdblcm --action=install --batch --autostart=1 -sid=$SID  --groupid=110 --hostname=$MASTER_HOSTNAME --number=$INSTANCE  --hdbinst_server_ignore=check_hardware --read_password_from_stdin=xml

#New fix: This will ensure the installation of all components except: lcapps and afl.  Both of these are optional and can be installed later directly by the customer.

cat $PASSFILE | $HANAMEDIA/HDB_LCM_LINUX_X86_64/hdblcm --action=install --components=client,hlm,server,studio --batch --autostart=1 -sid=$SID  --groupid=110 --hostname=$MASTER_HOSTNAME --number=$INSTANCE  --hdbinst_server_ignore=check_hardware --read_password_from_stdin=xml >> ${HANA_LOG_FILE} 2>&1

#Remove Password file
rm $PASSFILE


# ------------------------------------------------------------------
#	   Post HANA install
# ------------------------------------------------------------------

log "$(date) __ done installing HANA DB."..
log "$(date) __ changing the mode of the HANA folders..."

sid=`echo ${SID} | tr '[:upper:]' '[:lower:]'}`
adm="${sid}adm"

chown ${adm}:sapsys -R /backup/data/${SID}
chown ${adm}:sapsys -R /backup/log/${SID}

v_global="/usr/sap/${SID}/SYS/global/hdb/custom/config/global.ini"
v_daemon="/usr/sap/${SID}/SYS/global/hdb/custom/config/daemon.ini"

if [ -e "$v_global" ] ; then
   log "$(date) __ deleting the old entries in $v_global"
   sed -i '/^\[persistence\]/d' $v_global
   sed -i '/^basepath_shared/d' $v_global
   sed -i '/^savepoint_interval_s/d' $v_global
   sed -i '/^basepath_logbackup/d' $v_global
   sed -i '/^basepath_databackup/d'  $v_global
   sed -i '/^basepath_datavolumes/d' $v_global
   sed -i '/^basepath_logvolumes/d' $v_global
   sed -i '/^\[communication\]/d' $v_global
   sed -i '/^listeninterface /d' $v_global
fi

log "$(date) __ inserting the new entries in $v_global"
echo '[persistence]' >> $v_global
echo 'basepath_shared = no' >> $v_global
echo 'savepoint_interval_s = 300' >> $v_global
echo 'basepath_datavolumes = /hana/data/'${SID} >> $v_global
echo 'basepath_logvolumes = /hana/log/'${SID} >> $v_global
echo 'basepath_databackup = /backup/data/'${SID} >> $v_global
echo 'basepath_logbackup = /backup/log/'${SID} >> $v_global
echo '' >> $v_global
echo '[communication]' >> $v_global
echo 'listeninterface = .global' >> $v_global

if [ -e "$v_daemon" ] ; then
   log "$(date) __ deleting the old entries in $v_daemon"
   sed -i '/^\[scriptserver\]/d' $v_daemon
   sed -i '/^instances/d' $v_daemon
fi

log "$(date) __ inserting the new entries in $v_daemon"
echo '[scriptserver]' >> $v_daemon
echo 'instances = 1' >> $v_daemon

chown ${adm}:sapsys $v_daemon

log $(date)' __ done configuring HANA DB!'

su - $adm -c "hdbnsutil -reconfig --hostnameResolution=global"

#Restart after final config
log "Restarting HANA DB after customizing global.ini"
su - ${adm} -c "HDB stop 2>&1"
su - ${adm} -c "HDB start 2>&1"

#Copy Host Agent RPM for worker nodes
if [ -e "${HANAMEDIA}/SAP_HOST_AGENT_LINUX_X64/saphostagent.rpm" ]; then
   TRANS_SOFT=/hana/shared/$SID/trans/software
   mkdir $TRANS_SOFT
   chown ${adm}:sapsys $TRANS_SOFT
   cp ${HANAMEDIA}/SAP_HOST_AGENT_LINUX_X64/saphostagent.rpm $TRANS_SOFT
fi

#Modify HanaHwCheck.py to support multi-node deployments
HWCHECK="/hana/shared/$SID/exe/linuxx86_64/hdb/python_support/HanaHwCheck.py"
if [ -e "${HWCHECK}" ]; then
   sed -i "/performing Hardware/ a\ \t\treturn 0" ${HWCHECK}
else
   log "Unable to modify HanaHwCheck.py script.  Adding additional hosts may fail"
fi

log `date` END install-hana-master

