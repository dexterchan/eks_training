#!/bin/sh
#get private key
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.yaml

#Delete the previous private key
kubectl delete secret database-credentials -n octank
kubectl delete sealedsecret database-credentials -n octank
kubectl delete secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
kubectl delete -f controller.yaml 

#Apply the private key back
kubectl apply -f master.yaml 
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key

#redeploy the SealedSecret CRD, controller and RBAC artifacts on your EKS
kubectl apply -f controller.yaml
kubectl get pods -n kube-system | grep sealed-secrets-controller

#redeploy sealed secret
kubectl apply -f sealed-secret.yaml 
kubectl logs sealed-secrets-controller-84fcdcd5fd-gznc2  -n kube-system
