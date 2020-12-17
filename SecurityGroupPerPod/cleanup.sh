#!/bin/sh
STACK_NAME=$(eksctl get nodegroup --cluster eksworkshop-eksctl -o json | jq -r '.[].StackName')
export ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')

export VPC_ID=$(aws eks describe-cluster \
    --name eksworkshop-eksctl \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
export RDS_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=RDS_SG Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)
export POD_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=POD_SG Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)
export C9_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
export NODE_GROUP_SG=$(aws ec2 describe-security-groups \
    --filters Name=tag:Name,Values=eks-cluster-sg-eksworkshop-eksctl-* Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" \
    --output text)

# uninstall the RPM package
sudo yum erase -y postgresql

# delete database
aws rds delete-db-instance \
    --db-instance-identifier rds-eksworkshop \
    --delete-automated-backups \
    --skip-final-snapshot

# delete kubernetes element
kubectl -n sg-per-pod delete -f sg-per-pod/green-pod.yaml
kubectl -n sg-per-pod delete -f sg-per-pod/red-pod.yaml
kubectl -n sg-per-pod delete -f sg-per-pod/sg-policy.yaml
kubectl -n sg-per-pod delete secret rds

kubectl delete ns sg-per-pod

# disable ENI trunking
kubectl -n kube-system set env daemonset aws-node ENABLE_POD_ENI=false
kubectl -n kube-system rollout status ds aws-node

# remove the trunk label
kubectl label node  --all 'vpc.amazonaws.com/has-trunk-attached'-

# detach IAM policy
aws iam detach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController \
    --role-name ${ROLE_NAME}

# remove security group rules
aws ec2 revoke-security-group-ingress \
    --group-id ${RDS_SG} \
    --protocol tcp \
    --port 5432 \
    --source-group ${POD_SG}

aws ec2 revoke-security-group-ingress \
    --group-id ${RDS_SG} \
    --protocol tcp \
    --port 5432 \
    --cidr ${C9_IP}/32

aws ec2 revoke-security-group-ingress \
    --group-id ${NODE_GROUP_SG} \
    --protocol tcp \
    --port 53 \
    --source-group ${POD_SG}

aws ec2 revoke-security-group-ingress \
    --group-id ${NODE_GROUP_SG} \
    --protocol udp \
    --port 53 \
    --source-group ${POD_SG}

# delete POD SG
aws ec2 delete-security-group \
    --group-id ${POD_SG}
cd ~/environment

rm -rf sg-per-pod
