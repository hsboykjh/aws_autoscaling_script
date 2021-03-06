#!/bin/bash

#old scaling group name
OLD_AUTO_SCALING_GROUP_NAME=$(aws autoscaling describe-auto-scaling-groups | grep scaling-group | grep api-server-prod | awk '{print $3}')
echo "OLD_AUTO_SCALING_GROUP_NAME : "$OLD_AUTO_SCALING_GROUP_NAME

# deploy server to make new AMI
BUILD_INSTANCE=i-12345678
SERVER_SPEC=m3.large
#api-lb-security-group
SECURITY_GROUP=sg-0a1b2c3d4
#ELB (elastic load balancer)name
ELB_NAME=elb-name
#Server scaling number
SERVER_MAX=4
SERVER_MIN=2
SERVER_DEFAULT=1

#VPC ID
VPC_ID=vpc-a1b2c3d4
SUBNET_ID_1=subnet-a1b2c3d4
SUBNET_ID_2=subnet-a1b2c3d5
# current Date and Time ( hour/min )
DATE=$(date +%Y%m%d%H%M)
echo "current Date : "$DATE

# AMI naming : ex) api-server-prod-20160101
NAME_PREFIX="server-prod"
NAME=$NAME_PREFIX-$DATE
echo "new AMI name: "$NAME

# create temp file to store new AMI id
RESULTFILENAME=AMI$DATE

touch RESULTFILENAME
# create new AMI based on the deploy-server
aws ec2 create-image --instance-id $BUILD_INSTANCE --name $NAME --no-reboot > $RESULTFILENAME

NEW_AMI_ID=$(<$RESULTFILENAME)
echo "new AMI id: "$NEW_AMI_ID

rm $RESULTFILENAME

sleep 180

#Create New Launch Configuration
LAUNCH_CONFIGURATION_NAME=$NAME-launch-config
aws autoscaling create-launch-configuration --launch-configuration-name $LAUNCH_CONFIGURATION_NAME --image-id $NEW_AMI_ID --security-groups $SECURITY_GROUP --instance-type $SERVER_SPEC --instance-monitoring Enabled=true --no-ebs-optimized

echo "Create New Launch Configuration : $LAUNCH_CONFIGURATION_NAME is created"

sleep 180

AUTO_SCALING_GROUP_NAME=$NAME-scaling-group
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --launch-configuration-name $LAUNCH_CONFIGURATION_NAME --load-balancer-names $ELB_NAME --health-check-type ELB --health-check-grace-period 300 --max-size $SERVER_DEFAULT --min-size $SERVER_DEFAULT --desired-capacity $SERVER_DEFAULT --vpc-zone-identifier $SUBNET_ID_1,$SUBNET_ID_2

echo "Create New Auto-Scaling-Group : $AUTO_SCALING_GROUP_NAME is created"

# check load balance health check ( instance )

sleep 300

# update autoscaling-group 1=> MAX,  1=> MIN , condition
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --min-size $SERVER_MIN --max-size $SERVER_MAX
echo "$AUTO_SCALING_GROUP_NAME Server MIN: 1 => $SERVER_MIN , MAX 1 => $SERVER_MAX"

sleep 10

# update old version autoscaling-group MAX =>1,  MIN => 1
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $OLD_AUTO_SCALING_GROUP_NAME --min-size 1 --max-size 1
echo "$OLD_AUTO_SCALING_GROUP_NAME Server MIN: 1 , MAX 1 "

sleep 120

# update old version autoscaling-group MAX =>0,  MIN => 0
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $OLD_AUTO_SCALING_GROUP_NAME --min-size 0 --max-size 0
echo "$OLD_AUTO_SCALING_GROUP_NAME Server MIN: 0 , MAX 0 "

sleep 120

# deregister old version autoscaling group from load balancer =>  delete old version autoscaling group
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $OLD_AUTO_SCALING_GROUP_NAME
echo "$OLD_AUTO_SCALING_GROUP_NAME deleted"

NEW_AUTO_SCALING_GROUP_NAME=$(aws autoscaling describe-auto-scaling-groups | grep scaling-group | grep api-server-prod | awk '{print $3}')
echo "Current Auto Scaling Group : $NEW_AUTO_SCALING_GROUP_NAME"
