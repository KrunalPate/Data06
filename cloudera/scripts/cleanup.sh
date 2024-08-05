#!/bin/bash

# ------------------------------------------------------------------
#          Cleanup files
# ------------------------------------------------------------------

for f in /home/ec2-user/cloudera/cfn-replace.sh /home/ec2-user/cloudera/download.sh /home/ec2-user/cloudera/cloudera*.tar.gz
do
   if [ -f "$f" ]; then
      rm -rf "$f"
   fi
done

for d in /home/ec2-user/cloudera/aws
do
	if [ -d "$d" ]; then
	  # Control will enter here if $DIRECTORY exists.
	  rm -rf ${d}
	fi
done
