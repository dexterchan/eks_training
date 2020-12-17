#!/bin/sh
export workdir=$(pwd)
export RDS_PASSWORD=$(cat ${workdir}/sg-per-pod/rds_password)

export RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier rds-eksworkshop \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)
#Create  secret in K8s
kubectl create secret generic rds\
    --namespace=sg-per-pod \
    --from-literal="password=${RDS_PASSWORD}" \
    --from-literal="host=${RDS_ENDPOINT}"

kubectl -n sg-per-pod describe  secret rds

pushd ${workdir}/sg-per-pod

curl -s -O https://www.eksworkshop.com/beginner/115_sg-per-pod/deployments.files/green-pod.yaml
curl -s -O https://www.eksworkshop.com/beginner/115_sg-per-pod/deployments.files/red-pod.yaml

kubectl -n sg-per-pod apply -f green-pod.yaml

kubectl -n sg-per-pod rollout status deployment green-pod

export GREEN_POD_NAME=$(kubectl -n sg-per-pod get pods -l app=green-pod -o jsonpath='{.items[].metadata.name}')
kubectl -n sg-per-pod  logs -f ${GREEN_POD_NAME}

kubectl -n sg-per-pod apply -f red-pod.yaml
kubectl -n sg-per-pod rollout status deployment red-pod

export RED_POD_MAME=$(kubectl -n sg-per-pod get pods -l app=red-pod -o jsonpath='{.items[].metadata.name}')
kubectl -n sg-per-pod  logs -f ${RED_POD_MAME}

kubectl -n sg-per-pod  describe pod ${RED_POD_MAME} | head -11


