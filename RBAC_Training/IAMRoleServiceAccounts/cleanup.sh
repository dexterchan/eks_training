#!/bin/sh
export workpath=$(pwd)

kubectl delete -f ${workpath}/irsa/job-s3.yaml
kubectl delete -f ${workpath}/irsa/job-ec2.yaml

eksctl delete iamserviceaccount \
    --name iam-test \
    --namespace default \
    --cluster eksworkshop-eksctl \
    --wait

rm -rf ${workpath}/irsa/
