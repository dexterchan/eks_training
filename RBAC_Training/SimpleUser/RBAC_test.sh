#!/bin/sh
#Create IAM user
aws iam create-user --user-name rbac-user
aws iam create-access-key --user-name rbac-user | tee /tmp/create_output.json

cat << EoF > rbacuser_creds.sh
export AWS_SECRET_ACCESS_KEY=$(jq -r .AccessKey.SecretAccessKey /tmp/create_output.json)
export AWS_ACCESS_KEY_ID=$(jq -r .AccessKey.AccessKeyId /tmp/create_output.json)
EoF

#Next, we’ll define a k8s user called rbac-user, 
#and map to its IAM user counterpart. 
#Run the following to get the existing ConfigMap and save into a file called aws-auth.yaml:
kubectl get configmap -n kube-system aws-auth -o yaml > aws-auth.yaml

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
cat << EoF >> aws-auth.yaml
data:
  mapUsers: |
    - userarn: arn:aws:iam::${ACCOUNT_ID}:user/rbac-user
      username: rbac-user
EoF

kubectl apply -f aws-auth.yaml

. rbacuser_creds.sh

#Check login credential
aws sts get-caller-identity

#Now , test it by accessing the pods
kubectl get pods -n rbac-test
#Expected result
#Error from server (Forbidden): pods is forbidden: User "rbac-user" cannot list resource "pods" in API group "" in the namespace "rbac-test"
#So far, we only created user, not yet map into the role
#Just creating the user doesn’t give that user access to any resources in the cluster. In order to achieve that, we’ll need to define a role, and then bind the user to that role. We’ll do that next.

#Create the role
cat << EoF > rbacuser-role.yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: rbac-test
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["list","get","watch"]
- apiGroups: ["extensions","apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
EoF

#Create the role-binding
cat << EoF > rbacuser-role-binding.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: rbac-test
subjects:
- kind: User
  name: rbac-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EoF


#Apply the change
kubectl apply -f rbacuser-role.yaml
kubectl apply -f rbacuser-role-binding.yaml

#Run again
kubectl get pods -n rbac-test
#We got result

kubectl get pods -n kube-system
#Fail as expected
