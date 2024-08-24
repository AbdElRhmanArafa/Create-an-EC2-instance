#!/bin/bash

DATE=$(date '+%Y-%m-%d %H:%M:%S')
USER=$(whoami)
echo
echo "Running create-instance.sh on "$DATE "by "$USER
echo

# Check if AWS CLI is installed
if ! [ -x "$(command -v aws)" ]; then
    echo "AWS CLI is not installed. Please install it before running this script."
    exit 1
fi

# Hard coded values
region=$(aws configure get region)
echo "Region: "$region
instanceType="t2.small"
echo "Instance Type: "$instanceType
profile="default"
echo "Profile: "$profile

echo
echo "Looking up account values..."
echo

# check if region is set
if [[ "$region" == "" ]]; then
    echo "AWS_REGION is not set. Please set it before running this script."
    echo "use 'aws configure set region <region>' to set it."
    exit 1
fi

# get vpcId
echo "Getting VPC ID have tag Name=MomPopCafe VPC ..."
vpc=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values='MomPopCafe VPC'" \
    --region $region \
    --profile $profile | grep VpcId | cut -d '"' -f4 | sed -n 1p)
echo "VPC: "$vpc

# get subnetId
echo "Getting Subnet ID have tag Name=MomPopCafe Public Subnet 1 ..."
subnetId=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values='MomPopCafe Public Subnet 1'" \
    --region $region \
    --profile $profile \
    --query "Subnets[?contains(AvailabilityZone, '$(region)')]" | grep SubnetId | cut -d '"' -f4 | sed -n 1p)
echo "Subnet Id: "$subnetId

# Get keypair name
# Ask the user to defult  keypair   or  generate new keypair
echo
echo "Do you want to use an existing key pair or create a new one?"
read -p "Enter '1-existing' or '2-new': " keypairChoice

if [[ "$keypairChoice" == "1" ]]; then
    echo
    echo "Getting existing key pair..."
    key=$(aws ec2 describe-key-pairs \
        --profile $profile | grep KeyName | cut -d '"' -f4)
    echo "Key: "$key
elif [[ "$keypairChoice" == "2" ]]; then
    echo
    echo "Creating a new key pair..."
    key=$(aws ec2 create-key-pair \
        --key-name "mompopcafekey" \
        --query 'KeyMaterial' \
        --output text \
        --profile $profile >mompopcafekey.pem)
    echo "Key: mompopcafekey"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Get AMI ID
echo "Getting the latest Amazon Linux 2 AMI..."
imageId=$(aws ssm get-parameters \
    --names '/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2' \
    --profile $profile \
    --region $region | grep ami- | cut -d '"' -f4 | sed -n 2p)
echo "AMI ID: "$imageId

if [[ "$imageId" == "" ]]; then
    echo "Could not get the AMI ID. Exiting."
    exit 1
fi

#check for existing mompopcafe instance
existingEc2Instance=$(aws ec2 describe-instances \
    --region $region \
    --profile $profile \
    --filters "Name=tag:Name,Values=mompopcafeserver" "Name=instance-state-name,Values=running" |
    grep InstanceId | cut -d '"' -f4)
if [[ "$existingEc2Instance" != "" ]]; then
    echo
    echo "WARNING: Found existing running EC2 instance with instance ID "$existingEc2Instance"."
    echo "This script will not succeed if it already exists. "
    echo "Would you like to delete it? [Y/N]"
    echo ">>"

    validResp=0
    while [ $validResp -eq 0 ]; do
        read answer
        if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
            echo
            echo "Deleting the existing instance..."
            aws ec2 terminate-instances --instance-ids $existingEc2Instance --region $region --profile $profile
            #wait for confirmation it was terminated
            aws ec2 wait instance-terminated --instance-ids $existingEc2Instance --region $region --profile $profile
            validResp="1"
        elif [[ "$answer" == "N" || "$answer" == "n" ]]; then
            echo "Ok, exiting."
            exit 1
        else
            echo "Please reply with Y or N."
        fi
    done

    sleep 10 #give it 10 seconds before trying to delete the SG this instance used.
fi

#check for existing mompopcafeSG security Group
existingMpSg=$(aws ec2 describe-security-groups \
    --region $region \
    --query "SecurityGroups[?contains(GroupName, 'mompopcafeSG')]" \
    --profile $profile | grep GroupId | cut -d '"' -f4)

if [[ "$existingMpSg" != "" ]]; then
    echo
    echo "WARNING: Found existing security group with name "$existingMpSg"."
    echo "This script will not succeed if it already exists. "
    echo "Would you like to delete it? [Y/N]"
    echo ">>"

    validResp=0
    while [ $validResp -eq 0 ]; do
        read answer
        if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
            echo
            echo "Deleting the existing security group..."
            aws ec2 delete-security-group --group-id $existingMpSg --region $region --profile $profile
            validResp="1"
        elif [[ "$answer" == "N" || "$answer" == "n" ]]; then
            echo "Ok, exiting."
            exit 1
        else
            echo "Please reply with Y or N."
        fi
    done
    sleep 10 #give it 10 seconds before trying to recreate the SG
fi

# CREATE a security group and capture the name of it
echo
echo "Creating a new security group..."
securityGroup=$(aws ec2 create-security-group --group-name "mompopcafeSG" \
    --description "mompopcafeSG" \
    --region $region \
    --group-name "mompopcafeSG" \
    --vpc-id $vpc --profile $profile | grep GroupId | cut -d '"' -f4)
echo "Security Group: "$securityGroup

# Open ports in the security group
echo
echo "Opening port 22 in the new security group"
aws ec2 authorize-security-group-ingress \
    --group-id $securityGroup \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $region \
    --profile $profile

echo "Opening port 80 in the new security group"
aws ec2 authorize-security-group-ingress \
    --group-id $securityGroup \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $region \
    --profile $profile

echo
echo "Creating an EC2 instance in "$region
instanceDetails=$(aws ec2 run-instances \
    --image-id $imageId \
    --count 1 \
    --instance-type $instanceType \
    --region $region \
    --subnet-id $subnetId \
    --security-group-ids $securityGroup \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mompopcafeserver}]' \
    --associate-public-ip-address \
    --profile $profile \
    --user-data file://create-lamp-instance-userdata.txt)

#if the create instance command failed, exit this script
if [[ "$?" -ne "0" ]]; then
    exit 1
fi

echo
echo "Instance Details...."
echo $instanceDetails | python -m json.tool

# Extract instanceId
instanceId=$(echo $instanceDetails | python -m json.tool | grep InstanceId | sed -n 1p | cut -d '"' -f4)
echo "instanceId="$instanceId
echo
echo "Waiting for a public IP for the new instance..."
pubIp=""
while [[ "$pubIp" == "" ]]; do
    sleep 10
    pubIp=$(aws ec2 describe-instances --instance-id $instanceId --region $region --profile $profile | grep PublicIp | sed -n 1p | cut -d '"' -f4)
done

echo
echo "The public IP of your LAMP instance is: "$pubIp
echo
echo "Download the Key Pair from the Qwiklabs page."
echo
echo "Then connect using this command (with .pem or .ppk added to the end of the keypair name):"
echo "ssh -i path-to/"$key" ec2-user@"$pubIp
echo
echo "The website should also become available at"
echo "http://"$pubIp"/mompopcafe/"
# wait for url to be available
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' http://$pubIp/mompopcafe/)" != "200" ]]; do
    sleep 10
done

echo
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo
echo "Done running create-instance.sh at "$DATE
echo
