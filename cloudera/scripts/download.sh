#!/bin/bash

# ------------------------------------------------------------------
#          Download all the scripts needed for installing Cloudera
# ------------------------------------------------------------------

# first update time
yum -y install ntp
service ntpd start
ntpdate  -u 0.amazon.pool.ntp.org

LAUNCHPAD_DIR=cloudera-director-1.0.1

mkdir -p /home/ec2-user/cloudera/cloudera-director-1.0.1
mkdir -p /home/ec2-user/cloudera/cloudera-director-server-1.0.1
mkdir -p /home/ec2-user/cloudera/aws 

LAUNCHPAD_CLI_ZIP=cloudera-director-1.0.1.tar.gz
LAUNCHPAD_SERVER_ZIP=cloudera-director-server-1.0.1.tar.gz

for LAUNCHPAD_ZIP in ${LAUNCHPAD_CLI_ZIP} ${LAUNCHPAD_SERVER_ZIP}
do
	wget https://s3.amazonaws.com/quickstart-reference/cloudera/hadoop/latest/media/${LAUNCHPAD_ZIP} --output-document=/home/ec2-user/cloudera/${LAUNCHPAD_ZIP}
done

wget https://s3.amazonaws.com/aws-cli/awscli-bundle.zip --output-document=/home/ec2-user/cloudera/aws/awscli-bundle.zip
wget https://s3.amazonaws.com/quickstart-reference/cloudera/hadoop/latest/media/jq --output-document=/home/ec2-user/cloudera/aws/jq

tar xvf /home/ec2-user/cloudera/${LAUNCHPAD_CLI_ZIP} -C /home/ec2-user/cloudera/cloudera-director-1.0.1  --strip-components=1
tar xvf /home/ec2-user/cloudera/${LAUNCHPAD_SERVER_ZIP} -C /home/ec2-user/cloudera/cloudera-director-server-1.0.1 --strip-components=1

cd /home/ec2-user/cloudera/aws
unzip awscli-bundle.zip
./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
cd /home/ec2-user/cloudera/aws
chmod 755 ./jq
export JQ_COMMAND=/home/ec2-user/cloudera/aws/jq


AWS_SIMPLE_CONF=$(find /home/ec2-user/cloudera/ -name "aws.simple.conf")
AWS_REFERENCE_CONF=$(find /home/ec2-user/cloudera/ -name "aws.reference.conf")

wget https://s3.amazonaws.com/quickstart-reference/cloudera/hadoop/latest/media/aws.simple.conf --output-document=${AWS_SIMPLE_CONF}
wget https://s3.amazonaws.com/quickstart-reference/cloudera/hadoop/latest/media/aws.reference.conf --output-document=${AWS_REFERENCE_CONF}

cd /home/ec2-user/cloudera/cloudera-director-1.0.1

export AWS_INSTANCE_IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
export AWS_ACCESSKEYID=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/${AWS_INSTANCE_IAM_ROLE} | ${JQ_COMMAND} '.AccessKeyId'  | sed 's/^"\(.*\)"$/\1/')
export AWS_SECRETACCESSKEY=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/${AWS_INSTANCE_IAM_ROLE} | ${JQ_COMMAND} '.SecretAccessKey' | sed 's/^"\(.*\)"$/\1/')
export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | ${JQ_COMMAND} '.region'  | sed 's/^"\(.*\)"$/\1/') 
export AWS_INSTANCEID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | ${JQ_COMMAND} '.instanceId' | sed 's/^"\(.*\)"$/\1/' )

# Not a clean way. But querying 6.4 is painful without hardcoding owner ID. Fix it next time

export AWS_HVM_AMI=$(/usr/local/bin/aws ec2 describe-images --filter \
					"Name=architecture,Values=x86_64" "Name=virtualization-type,Values=hvm" \
					"Name=name,Values=RHEL-6.4*" "Name=owner-id,Values=309956199498" \
					"Name=is-public,Values=true" "Name=state,Values=available" \
					| /home/ec2-user/cloudera/aws/jq '.Images[].ImageId' | sort -R | head -1 \
					| sed 's/^"\(.*\)"$/\1/')


export AWS_PVM_AMI=$(/usr/local/bin/aws ec2 describe-images --filter \
					"Name=architecture,Values=x86_64" "Name=virtualization-type,Values=paravirtual" \
					"Name=name,Values=RHEL-6.4*" "Name=owner-id,Values=309956199498" \
					"Name=is-public,Values=true" "Name=state,Values=available" \
					| /home/ec2-user/cloudera/aws/jq '.Images[].ImageId' | sort -R | head -1 \
					| sed 's/^"\(.*\)"$/\1/')


# Replace these via CloudFormation User-Data
export AWS_SUBNETID=SUBNETID-CFN-REPLACE
export AWS_PRIVATESUBNETID=PRIVATESUBNETID-CFN-REPLACE
export AWS_PUBLICSUBNETID=PUBLICSUBNETID-CFN-REPLACE

export AWS_SECURITYGROUPIDS=SECUTIRYGROUPIDS-CFN-REPLACE
export AWS_KEYNAME=KEYNAME-CFN-REPLACE
export AWS_CDH_INSTANCE=HADOOPINSTANCE-TYPE-CFN-REPLACE
export AWS_CDH_COUNT=HADOOPINSTANCE-COUNT-CFN-REPLACE

declare -A IsPVMSupported
declare -A IsHVMSupported

IsPVMSupported=( ["m3.xlarge"]=1
				["m3.2xlarge"]=1
				["m1.small"]=1
				["m1.medium"]=1
				["m1.large"]=1
				["m1.xlarge"]=1
				["c3.large"]=1
				["c3.xlarge"]=1
				["c3.2xlarge"]=1
				["c3.4xlarge"]=1
				["c3.8xlarge"]=1
				["c1.medium"]=1
				["c1.xlarge"]=1
				["cc2.8xlarge"]=0
				["g2.2xlarge"]=0
				["cg1.4xlarge"]=0
				["m2.xlarge"]=1
				["m2.2xlarge"]=1
				["m2.4xlarge"]=1
				["cr1.8xlarge"]=0
				["hi1.4xlarge"]=1
				["hs1.8xlarge"]=1
				["i2.xlarge"]=0
				["i2.2xlarge"]=0
				["i2.4xlarge"]=0
				["i2.8xlarge"]=0
				["r3.large"]=0
				["r3.xlarge"]=0
				["r3.2xlarge"]=0
				["r3.4xlarge"]=0
				["r3.8xlarge"]=0
				["t1.micro"]=1
				["t2.micro"]=0
				["t2.small"]=0
				["t2.medium"]=0
)

IsHVMSupported=( ["m3.xlarge"]=1
				["m3.xlarge"]=1
				["m3.2xlarge"]=1
				["m1.small"]=1
				["m1.medium"]=1
				["m1.large"]=0
				["m1.xlarge"]=0
				["c3.large"]=1
				["c3.xlarge"]=1
				["c3.2xlarge"]=1
				["c3.4xlarge"]=1
				["c3.8xlarge"]=1
				["c1.medium"]=1
				["c1.xlarge"]=1
				["cc2.8xlarge"]=1
				["g2.2xlarge"]=1
				["cg1.4xlarge"]=1
				["m2.xlarge"]=0
				["m2.2xlarge"]=0
				["m2.4xlarge"]=0
				["cr1.8xlarge"]=1
				["hi1.4xlarge"]=1
				["hs1.8xlarge"]=1
				["i2.xlarge"]=1
				["i2.2xlarge"]=1
				["i2.4xlarge"]=1
				["i2.8xlarge"]=1
				["r3.large"]=1
				["r3.xlarge"]=1
				["r3.2xlarge"]=1
				["r3.4xlarge"]=1
				["r3.8xlarge"]=1
				["t1.micro"]=0
				["t2.micro"]=1
				["t2.small"]=1
				["t2.medium"]=1
)

ishvm=${IsHVMSupported[${AWS_CDH_INSTANCE}]}
if [ -z ${ishvm} ]; then
	export AWS_AMI=${AWS_HVM_AMI}
elif [ ${ishvm} -eq 1 ];then
	export AWS_AMI=${AWS_HVM_AMI}
else
	export AWS_AMI=${AWS_PVM_AMI}
fi

# Escape / to keep sed happy
# This is not used currently.
AWS_ACCESSKEYID=$(echo $AWS_ACCESSKEYID | sed 's/\//\\\//g')
AWS_SECRETACCESSKEY=$(echo $AWS_SECRETACCESSKEY | sed 's/\//\\\//g')

CURRENT_DATE=$(date +"%m-%d-%Y")
AWS_PLACEMENT_GROUP_NAME=AWS-PLACEMENT-GROUP-${AWS_DEFAULT_REGION}-${CURRENT_DATE}

# Create PlacementGroup
/usr/local/bin/aws ec2 create-placement-group --group-name ${AWS_PLACEMENT_GROUP_NAME} --strategy cluster


	# For private subnet, use subnetId: privatesubnetId-REPLACE-ME
	# For public subnet, use subnetId: publicsubnetId-REPLACE-ME


for AWS_CONF_FILE in ${AWS_SIMPLE_CONF} ${AWS_REFERENCE_CONF}
do
	sed -i "s/accessKeyId-REPLACE-ME/${AWS_ACCESSKEYID}/g" ${AWS_CONF_FILE}
	sed -i "s/secretAccessKey-REPLACE-ME/${AWS_SECRETACCESSKEY}/g" ${AWS_CONF_FILE}
	sed -i "s/region-REPLACE-ME/${AWS_DEFAULT_REGION}/g" ${AWS_CONF_FILE}
	sed -i "s/privatesubnetId-REPLACE-ME/${AWS_PRIVATESUBNETID}/g" ${AWS_CONF_FILE}
	sed -i "s/publicsubnetId-REPLACE-ME/${AWS_PUBLICSUBNETID}/g" ${AWS_CONF_FILE}
	sed -i "s/subnetId-REPLACE-ME/${AWS_SUBNETID}/g" ${AWS_CONF_FILE}
	sed -i "s/securityGroupsIds-REPLACE-ME/${AWS_SECURITYGROUPIDS}/g" ${AWS_CONF_FILE} 
	sed -i "s/keyName-REPLACE-ME/${AWS_KEYNAME}/g" ${AWS_CONF_FILE} 
	sed -i "s/type-REPLACE-ME/${AWS_CDH_INSTANCE}/g" ${AWS_CONF_FILE}
	sed -i "s/count-REPLACE-ME/${AWS_CDH_COUNT}/g" ${AWS_CONF_FILE}
	sed -i "s/image-REPLACE-ME/${AWS_AMI}/g" ${AWS_CONF_FILE}
	sed -i "s/hvm-ami-REPLACE-ME/${AWS_HVM_AMI}/g" ${AWS_CONF_FILE}
	sed -i "s/pvm-ami-REPLACE-ME/${AWS_PVM_AMI}/g" ${AWS_CONF_FILE}
	sed -i "s/placementGroup-REPLACE-ME/${AWS_PLACEMENT_GROUP_NAME}/g" ${AWS_CONF_FILE}	
	sed -i "s/instanceNamePrefix.*/instanceNamePrefix: cloudera-director-${AWS_INSTANCEID}/g" ${AWS_CONF_FILE}
	
done

# change ownership
chown -R ec2-user /home/ec2-user/cloudera
