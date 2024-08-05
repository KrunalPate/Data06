#!/bin/bash

# ------------------------------------------------------------------
#          Download all the scripts needed for HANA install
# ------------------------------------------------------------------
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/cluster-watch-engine.sh --output-document=/root/install/cluster-watch-engine.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-prereq.sh --output-document=/root/install/install-prereq.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-aws.sh --output-document=/root/install/install-aws.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-master.sh  --output-document=/root/install/install-master.sh 
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-master-fake.sh  --output-document=/root/install/install-master-fake.sh 
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-hana-master.sh --output-document=/root/install/install-hana-master.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-worker.sh --output-document=/root/install/install-worker.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-worker-fake.sh --output-document=/root/install/install-worker-fake.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/install-hana-worker.sh --output-document=/root/install/install-hana-worker.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/reconcile-ips.py --output-document=/root/install/reconcile-ips.py
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/reconcile-ips.sh --output-document=/root/install/reconcile-ips.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/wait-for-master.sh --output-document=/root/install/wait-for-master.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/wait-for-workers.sh --output-document=/root/install/wait-for-workers.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/config.sh --output-document=/root/install/config.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/cleanup.sh --output-document=/root/install/cleanup.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/log2s3.sh --output-document=/root/install/log2s3.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/debug-log.sh --output-document=/root/install/debug-log.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/fence-cluster.sh --output-document=/root/install/fence-cluster.sh
wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/scripts/signal-complete.sh --output-document=/root/install/signal-complete.sh
