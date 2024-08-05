#!/bin/bash 


# ------------------------------------------------------------------
#          This script installs HANA worker node
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() { 
    cat <<EOF
    Usage: $0 [options]
        -h print usage        
        -p HANA MASTER PASSWD
        -s SID
        -n MASTER HOSTNAME
        -d DOMAIN 
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}

# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------



while getopts ":h:p:s:n:d:l:" o; do
    case "${o}" in
        h) usage && exit 0
            ;;
        p) HANAPASSWORD=${OPTARG}
            ;;
        s) SID=${OPTARG}
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

[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MHOSTNAME missing" && usage;
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


log `date` BEGIN install-hana-worker 


# ------------------------------------------------------------------
#          Helper functions
#          install_worker()
#          retry_mount()
# ------------------------------------------------------------------


install_worker() {

HOSTAGENT=/hana/shared/$SID/trans/software/saphostagent.rpm
HDBADDHOST=/hana/shared/$SID/global/hdb/install/bin/hdbaddhost

#fix permissions for install
chmod 777 /hana/log/$SID /hana/data/$SID

#Hostagent
if [ -e ${HOSTAGENT} ]; then
    log "Installing Host Agent"
    rpm -i ${HOSTAGENT}
    service sapinit start
fi
 
if [ -e ${HDBADDHOST} ]; then
    ${HDBADDHOST} --role=worker --sapmnt=/hana/shared --password=$HANAPASSWORD --sid=$SID 
    return 0
  else
    log "hdbaddhost program not available, ensure /hana/shared is mounted from $MASTER_HOSTNAME"
    return 1
 fi

#Remove Password file
#rm $PASSFILE

#Fix permissions after install
chmod 755 /hana/data/$SID /hana/log/$SID
}



retry_mount() {
  log "retrying /hana/share mount"
  service autofs restart
  if [ ! -e ${HDBADDHOST} ]; then
     mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/hana/shared /hana/shared
     mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/backup /backup
  log "Hard mounted NFS mounts, consider adding to /etc/fstab"
  fi
}


# ------------------------------------------------------------------
#          Main install code
# ------------------------------------------------------------------


if install_worker; then
   log "Host Added..."
 else
   if retry_mount; then
      if install_worker; then
         log "Host Added..." 
      fi
   else
      log "unable to mount /hana/shared filesystem from $MASTER_HOSTNAME"
   fi      
fi

#log "$(date) __ changing the mode of the HANA folder..."
#hdb=`echo ${SID} | tr '[:upper:]' '[:lower:]'}`
#adm="${hdb}adm"

#chown ${adm}:sapsys -R /hana/data/${SID}
#chown ${adm}:sapsys -R /hana/log/${SID}

#set password for sapadm user   
echo -e "$HANAPASSWORD\n$HANAPASSWORD" | (passwd --stdin sapadm)

#chmod 775 /usr/sap/hostctrl/work
#chmod 770 /usr/sap/hostctrl/work/sapccmsr

log "restarting host agent"
/usr/sap/hostctrl/exe/saphostexec -restart

log `date` END install-hana-worker 

exit 0
