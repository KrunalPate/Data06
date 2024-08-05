#
# ------------------------------------------------------------------
#          Install aws cli tools and jq
# ------------------------------------------------------------------


SCRIPT_DIR=/root/install/
cd ${SCRIPT_DIR}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

log `date` BEGIN install-aws

wget https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
#wget http://stedolan.github.io/jq/download/linux64/jq
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/media/jq
chmod 755 ./jq
cd -

log `date` END install-aws

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi
zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
zypper -n install tcsh  | tee -a ${HANA_LOG_FILE}

exit 0








