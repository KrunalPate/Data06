#!/bin/bash


# ------------------------------------------------------------------
# Remove user-data for security purpose
# Removes from the instance this command is run
# ------------------------------------------------------------------


JQ_COMMAND=/root/install/jq
export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin

usage() { 
    cat <<EOF
    Usage: $0
        -h print usage 
EOF
    exit 0
}

[[ $# -ne 0 ]] && usage;

source /root/install/config.sh 
export AWS_DEFAULT_REGION=${REGION}


