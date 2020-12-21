#!/bin/sh

#wget https://eksworkshop.com/beginner/200_secrets/secrets.files/kustomization.yaml
# Kustomize provides resource Generators to create Secrets and ConfigMaps. 
#Note it is only a base64 encode
kubectl kustomize . > secret.yaml

#Apply the secret

#Publish the credential as environment variable
wget https://eksworkshop.com/beginner/200_secrets/secrets.files/pod-variable.yaml
kubectl apply -f pod-variable.yaml
kubectl get pod -n octank

#Publish the credential as disk volume
wget https://eksworkshop.com/beginner/200_secrets/secrets.files/pod-volume.yaml
kubectl apply -f pod-volume.yaml
kubectl get pod -n octank

