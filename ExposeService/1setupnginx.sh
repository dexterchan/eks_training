#!/bin/sh
export workdir=$(pwd)
cat <<EoF > ${workdir}/run-my-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
  namespace: my-nginx
spec:
  selector:
    matchLabels:
      run: my-nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
EoF

# create the namespace
kubectl create ns my-nginx
# create the nginx deployment with 2 replicas
kubectl -n my-nginx apply -f ${workdir}/run-my-nginx.yaml

kubectl -n my-nginx get pods -o wide

kubectl -n my-nginx get pods -o yaml | grep 'podIP:'

#expose pod to service
kubectl -n my-nginx expose deployment/my-nginx

# Create a variable set with the my-nginx service IP
export MyClusterIP=$(kubectl -n my-nginx get svc my-nginx -ojsonpath='{.spec.clusterIP}')

# Create a new deployment and allocate a TTY for the container in the pod
kubectl -n my-nginx run -i --tty load-generator --env="MyClusterIP=${MyClusterIP}" --image=busybox /bin/sh

#Service is missing
export mypod=$(kubectl -n my-nginx get pods -l run=my-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl -n my-nginx exec ${mypod} -- printenv | grep SERVICE

#destroy the pod again
kubectl -n my-nginx get pods -l run=my-nginx -o wide

#Run again
export mypod=$(kubectl -n my-nginx get pods -l run=my-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl -n my-nginx exec ${mypod} -- printenv | grep SERVICE
#See the service in env varibale "MY_NGINX_SERVICE_HOST"

#Check K8s DNS
kubectl get service -n kube-system -l k8s-app=kube-dns

#Run tty
kubectl -n my-nginx run curl --image=radial/busyboxplus:curl -i --tty --generator=run-pod/v1
#>nslookup my-nginx
#> show all DNS entries

kubectl -n my-nginx get svc my-nginx

#Quick update to set LoadBalancer from ClusterIP in the service:
kubectl -n my-nginx patch svc my-nginx -p '{"spec": {"type": "LoadBalancer"}}'

#Create OIDC provider (enable entitlement to K8s service to request AWS resource)
eksctl utils associate-iam-oidc-provider \
    --region ${AWS_REGION} \
    --cluster eksworkshop-eksctl \
    --approve

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
#Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
    
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
#Create K8s service account
eksctl create iamserviceaccount \
  --cluster eksworkshop-eksctl \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

#Install the TargetGroupBinding CRDs
#Custom Resource Definition
kubectl apply -k github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master

kubectl get crd

#Deploy helm chart
helm repo add eks https://aws.github.io/eks-charts

helm upgrade -i aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=eksworkshop-eksctl \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set image.tag="${LBC_VERSION}"
#Deploy ingress controller of aws-load-balancer-controller
kubectl -n kube-system rollout status deployment aws-load-balancer-controller

#Deploy a sample app
curl -s https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/examples/2048/2048_full.yaml \
    | sed 's=alb.ingress.kubernetes.io/target-type: ip=alb.ingress.kubernetes.io/target-type: instance=g' \
    | kubectl apply -f -
#Get ingress info
kubectl get ingress/ingress-2048 -n game-2048

#Get target group info
export GAME_INGRESS_NAME=$(kubectl -n game-2048 get targetgroupbindings -o jsonpath='{.items[].metadata.name}')

kubectl -n game-2048 get targetgroupbindings ${GAME_INGRESS_NAME} -o yaml



    
    

