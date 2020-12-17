#!/bin/sh

STACK_NAME=$(eksctl get nodegroup --cluster eksworkshop-eksctl -o json | jq -r '.[].StackName')
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')

#Attach VPC Policy
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController \
    --role-name ${ROLE_NAME}

#Enable CNI plugin
kubectl -n kube-system set env daemonset aws-node ENABLE_POD_ENI=true

# let's way for the rolling update of the daemonset
kubectl -n kube-system rollout status ds aws-node

#Once this setting is set to true, for each node in the cluster the plugin adds a label
#with the value vpc.amazonaws.com/has-trunk-attached=true.
popd

export VPC_ID=$(aws eks describe-cluster \
    --name eksworkshop-eksctl \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
export POD_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=POD_SG Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)
    
cat << EoF > sg-per-pod/sg-policy.yaml
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: allow-rds-access
spec:
  podSelector:
    matchLabels:
      app: green-pod
  securityGroups:
    groupIds:
      - ${POD_SG}
EoF

kubectl create namespace sg-per-pod

kubectl -n sg-per-pod apply -f sg-per-pod/sg-policy.yaml
kubectl -n sg-per-pod describe securitygrouppolicy

