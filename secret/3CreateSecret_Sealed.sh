#!/bin/sh
#clean up previous secret with base64
kubectl delete secret database-credentials -n octank
kubectl get secret -n octank
#only left with default secret by K8s

#Regenerate secret.yaml from kustomization.yaml
kubectl kustomize . > secret.yaml
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

#or
kubeseal --fetch-cert > public-key-cert.pem
kubeseal --cert=public-key-cert.pem --format=yaml < secret.yaml > sealed-secret.yaml

#apply secret
kubectl apply -f sealed-secret.yaml 

kubectl delete pod pod-variable -n octank
kubectl apply -f pod-variable.yaml -n octank
kubectl logs pod-variable -n octank

#Now, sealed-secret.yaml is safe to be stored in repository since it is encrypted by envelope encryption of the public key