#!/bin/bash

# Don't enable debug mode in this script as secrets will ends-up in the logs!
set -eo pipefail

# Backward compatibility, passed by the Terraform template to cloud.init user_data
bootstrap_version="${bootstrap_version}"

INSTANCE_ID=$(ec2metadata --instance-id)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
WAIT_TIME=0
while [[ -z "$bootstrap_version" || "$bootstrap_version" == "None" && $WAIT_TIME -lt 60 ]]; do
    bootstrap_version=$(aws ec2 describe-tags \
        --region=$REGION \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=bootstrap_version" \
        --query 'Tags[0].Value' \
        --output=text \
    )
    sleep $WAIT_TIME
    let WAIT_TIME=WAIT_TIME+10
done

if [ ! -d "/infrastructure" ] ; then
    git clone -b $bootstrap_version --single-branch https://github.com/aeternity/infrastructure.git /infrastructure
else
    git -C /infrastructure fetch origin $bootstrap_version
    git -C /infrastructure reset --hard FETCH_HEAD
fi

bash /infrastructure/scripts/bootstrap.sh
