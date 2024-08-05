#
# ------------------------------------------------------------------
#         Signal Completion of Wait Handle
# ------------------------------------------------------------------


SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

usage() { 
    cat <<EOF
    Usage: $0 [WAIT-HANDLE]
EOF
    exit 0
}


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


[[ $# -ne 1 ]] && usage;


log `date` signal-complete
SIGNAL=$*
log `date` END signal-complete

curl -X PUT -H 'Content-Type:' --data-binary '{"Status" : "SUCCESS","Reason" : "The HANA Master server has been installed and is ready","UniqueId" : "HANAMaster","Data" : "Done"}'  ${SIGNAL}

exit 0








