#
# ------------------------------------------------------------------
#          Install aws cli tools and jq
# ------------------------------------------------------------------

S3BUCKET=$1

SCRIPT_DIR=/root/install/
cd ${SCRIPT_DIR}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


DEBUG2S3=0
if [ -n "${DEBUG2S3}" ] ; then
	log `date` BEGIN DEBUG LOG
	MYTAG=$(hostname)
	sh /root/install/log2s3.sh -f /var/log/messages,/root/install/install.log,/root/install/config.sh -t ${MYTAG} -b ${S3BUCKET} -p 10 -e 3600 &
fi

exit 0








