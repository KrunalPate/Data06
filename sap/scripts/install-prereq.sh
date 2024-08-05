#!/bin/bash



# ------------------------------------------------------------------
# 
#          Install SAP HANA prerequisites (master node)
# 
# ------------------------------------------------------------------


usage() { 
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}


SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh


# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


while getopts ":l:" o; do
    case "${o}" in
        l)
            HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;


# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    if [ ! -d "/root/install/" ]; then
      mkdir -p "/root/install/"
    fi
    HANA_LOG_FILE=/root/install/install.log
fi

# ------------------------------------------------------------------
#         Disable hostname reset via DHCP
# ------------------------------------------------------------------
sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp

#restart network
service network restart


# ------------------------------------------------------------------
#          Install all the pre-requisites for SAP HANA
# ------------------------------------------------------------------

log "## Installing HANA Prerequisites...## "

zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
zypper se xulrunner  | tee -a ${HANA_LOG_FILE}
zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
chkconfig kdump off
echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf 
sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

#ipcs -l  | tee -a ${HANA_LOG_FILE}
#echo "kernel.shmmni=65536" >> /etc/sysctl.conf 
#sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

# ------------------------------------------------------------------
#          Start ntp server
# ------------------------------------------------------------------

echo "server 0.pool.ntp.org" >> /etc/ntp.conf
echo "server 1.pool.ntp.org" >> /etc/ntp.conf
echo "server 2.pool.ntp.org" >> /etc/ntp.conf
echo "server 3.pool.ntp.org" >> /etc/ntp.conf
service ntp start  | tee -a ${HANA_LOG_FILE}
chkconfig ntp on  | tee -a ${HANA_LOG_FILE}


# ------------------------------------------------------------------
#          We need ntfs-3g to mount Windows drive
# ------------------------------------------------------------------

zypper -n install ntfs-3g  | tee -a ${HANA_LOG_FILE}


zypper install libgcc_s1 libstdc++6
zypper remove ulimit
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/init.d/boot.local

log "## Completed HANA Prerequisites installation ## "

#USE_OPENSUSE_NTFS=1
if [ -z "${USE_OPENSUSE_NTFS}" ] ; then
	zypper -n install gcc
##	wget http://tuxera.com/opensource/ntfs-3g_ntfsprogs-2014.2.15.tgz
	wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/media/ntfs-3g_ntfsprogs-2014.2.15.tgz
	tar -zxvf ntfs-3g_ntfsprogs-2014.2.15.tgz
	(cd ntfs-3g_ntfsprogs-2014.2.15 && ./configure)
	(cd ntfs-3g_ntfsprogs-2014.2.15 && make)
	(cd ntfs-3g_ntfsprogs-2014.2.15 && make install)
	rm -rf ntfs-3g_ntfsprogs-2014.2.15*
else
	###Need to check the best way to install ntfs
	zypper ar "http://download.opensuse.org/repositories/filesystems/SLE_11_SP2/" "filesystems"
	zypper  install ntfs-3g
fi

sed -i '/preserve_hostname/ c\preserve_hostname: true' /etc/cloud/cloud.cfg

exit 0






