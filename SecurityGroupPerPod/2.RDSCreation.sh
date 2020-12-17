#!/bin/sh


export VPC_ID=$(aws eks describe-cluster \
    --name eksworkshop-eksctl \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
#We first need to create a DB subnet groups. We will use the same subnets as our EKS cluster.
export PUBLIC_SUBNETS_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=eksctl-eksworkshop-eksctl-cluster/SubnetPublic*" \
    --query 'Subnets[*].SubnetId' \
    --output json | jq -c .)

# create a db subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name rds-eksworkshop \
    --db-subnet-group-description rds-eksworkshop \
    --subnet-ids ${PUBLIC_SUBNETS_ID}


export workpath=$(pwd)
mkdir -p ${workpath}/sg-per-pod

# get RDS SG ID
export RDS_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=RDS_SG Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)

# generate a password for RDS
export RDS_PASSWORD="$(date | md5sum  |cut -f1 -d' ')"
echo ${RDS_PASSWORD}  > ${workpath}/sg-per-pod/rds_password


# create RDS Postgresql instance
aws rds create-db-instance \
    --db-instance-identifier rds-eksworkshop \
    --db-name eksworkshop \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --db-subnet-group-name rds-eksworkshop \
    --vpc-security-group-ids $RDS_SG \
    --master-username eksworkshop \
    --publicly-accessible \
    --master-user-password ${RDS_PASSWORD} \
    --backup-retention-period 0 \
    --allocated-storage 20

# verify the database status
aws rds describe-db-instances \
    --db-instance-identifier rds-eksworkshop \
    --query "DBInstances[].DBInstanceStatus" \
    --output text
    
#get database endpoint
# get RDS endpoint
export RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier rds-eksworkshop \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

echo "RDS endpoint: ${RDS_ENDPOINT}"

#create some content
sudo yum install -y postgresql

pushd sg-per-pod

cat << EoF > pgsql.sql
CREATE TABLE welcome (column1 TEXT);
insert into welcome values ('--------------------------');
insert into welcome values ('Welcome to the eksworkshop');
insert into welcome values ('--------------------------');
EoF

export RDS_PASSWORD=$(cat rds_password)

psql postgresql://eksworkshop:${RDS_PASSWORD}@${RDS_ENDPOINT}:5432/eksworkshop \
    -f pgsql.sql

popd


