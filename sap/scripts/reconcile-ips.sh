#!/bin/bash



# ------------------------------------------------------------------
#     Front to python code
# ------------------------------------------------------------------

usage() { 
    cat <<EOF
    Usage: $0 <HostCount>
EOF
    exit 1
}

[[ $# -ne 1 ]] && usage;

SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

nWorkers=$1

echo "" >> /etc/hosts
/usr/local/aws/bin/python /root/install/reconcile-ips.py -c ${nWorkers}
echo "" >> /etc/hosts
