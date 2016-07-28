#!/bin/bash
# deploy server to make new AMI
BUILD_INSTANCE=i-9d450f02
SERVER_SPEC=m3.large
#api-lb-security-group
SECURITY_GROUP=sg-0b4b1b6e
#ELB (elastic load balancer)name
ELB_NAME=aim-api-lb
#Server scaling number
SERVER_MAX=4
SERVER_MIN=2
SERVER_DEFAULT=1

#VPC ID
VPC_ID=	vpc-4a825d2f
SUBNET_ID_1=subnet-5de14d2a
SUBNET_ID_2=subnet-a5c107fc
# current Date and Time ( hour/min )
DATE=$(date +%Y%m%d%H%M)
echo $DATE

# AMI naming : ex) api-server-prod-20160101
NAME_PREFIX="api-server-prod"
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

#'#!/bin/bash
#cd
#cp -f /home/ec2-user/api-server/newrelic.yml /home/ec2-user/newrelic/newrelic.yml
#mkdir ./weldoneTest
#./start-server.sh'

echo "Create New Auto-Scaling-Group : $AUTO_SCALING_GROUP_NAME is created"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name sg-0b4b1b6e --launch-configuration-name api-server-prod-201607281139-launch-config --load-balancer-names aim-api-lb --health-check-type EC2 --health-check-grace-period 300 --max-size 1 --min-size 1 --desired-capacity 1 --vpc-zone-identifier subnet-5de14d2a,subnet-a5c107fc

