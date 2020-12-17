#!/bin/sh
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
#Gives Access to our IAM Roles to EKS Cluster
#add specific mapRoles to the aws-auth ConfigMap

#Update the aws-auth ConfigMap to allow our IAM roles
eksctl create iamidentitymapping \
  --cluster eksworkshop-eksctl \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/k8sDev \
  --username dev-user

eksctl create iamidentitymapping \
  --cluster eksworkshop-eksctl \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/k8sInteg \
  --username integ-user

eksctl create iamidentitymapping \
  --cluster eksworkshop-eksctl \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/k8sAdmin \
  --username admin \
  --group system:masters

#Display the configmap
kubectl get cm -n kube-system aws-auth -o yaml
eksctl get iamidentitymapping --cluster eksworkshop-eksctl
