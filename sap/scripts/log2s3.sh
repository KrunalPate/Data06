#!/bin/bash

# ------------------------------------------------------------------
#          This script logs files to S3 bucket
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() { 
    cat <<EOF
    Usage: $0 [options]
        -h print usage        
        -f f1,f2,f3 files
        -t tag
		-b S3 Bucket Name
        -p periodicity 
        -e expiry in seconds 
EOF
    exit 1
}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------

while getopts ":h:f:t:b:p:e:" o; do
    case "${o}" in
        h) usage && exit 0
            ;;
        f) FILE_LIST=${OPTARG}
            ;;
        t) TAG=${OPTARG}
            ;;
        b) S3BUCKET=${OPTARG}
            ;;
        p) PERIODICITY=${OPTARG}
            ;;
        e)
           EXPIRY_IN_SECS=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------

[[ -z "$S3BUCKET" ]]  && echo "input S3BUCKET missing" && usage;
[[ -z "$FILE_LIST" ]]  && echo "input FILE_LIST missing" && usage;
[[ -z "$TAG" ]]  && echo "input TAG missing" && usage;
[[ -z "$PERIODICITY" ]]  && echo "input PERIODICITY Name missing" && usage;
[[ -z "$EXPIRY_IN_SECS" ]]  && echo "input EXPIRY_IN_SECS Name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

START_TIME=`date +%s`
END_TIME=`date +%s`
let END_TIME=END_TIME+$EXPIRY_IN_SECS

TEMP_FILE=$(mktemp)
while [ $(( $(date +%s))) -lt $END_TIME ]; do
    echo `date +%s`
	OIFS=$IFS;
	IFS=",";
	FilesArray=($FILE_LIST);

	for ((i=0; i<${#FilesArray[@]}; ++i));
	do
	    log="${FilesArray[$i]}"
		if [ -e $log ]; then
		    key=$(basename $log)
		    sudo cp $log $TEMP_FILE
			/usr/local/bin/aws s3 cp $TEMP_FILE s3://${S3BUCKET}/${TAG}/${key} --acl public-read
			echo /usr/local/bin/aws s3 cp $TEMP_FILE s3://${S3BUCKET}/${TAG}/${key} --acl public-read
		fi
	done
	IFS=$OIFS;
	sleep $PERIODICITY
done


