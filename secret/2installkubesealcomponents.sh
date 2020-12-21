#!/bin/sh
#INstall kubeseal
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.10.0/kubeseal-linux-amd64 -O kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

#Installing the Custom Controller and CRD for SealedSecret
wget https://eksworkshop.com/beginner/200_secrets/secrets.files/controller.yaml
kubectl apply -f controller.yaml

#Check if running
kubectl get pods -n kube-system | grep sealed-secrets-controller
#You will find the certificate there in the log

kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml
