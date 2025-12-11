# AWS AppRunner VPC Networking Tutorial - CLI Version

This document contains the AWS CLI commands for setting up AWS AppRunner with VPC connectivity to access private EC2 instances. For the console-based tutorial, see [README.md](./README.md).

## Architecture Overview

The tutorial creates:
- A VPC with public and private subnets across multiple AZs
- A NAT Gateway for outbound internet access from private subnets
- An EC2 instance in a private subnet running nginx
- An AppRunner service with VPC Connector for private network access
- A Node.js application that demonstrates connectivity by making HTTP requests to the EC2 instance's private IP

## Prerequisites

- AWS CLI configured with appropriate permissions
- Basic understanding of VPC networking concepts
- Node.js application (provided in this repository)

## CLI Tutorial Steps

### Step 1: Create VPC with Public/Private Setup and NAT Gateway

#### 1.1 Create the VPC
```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=apprunner-vpc}]'

# Note the VPC ID from the output
export VPC_ID=<your-vpc-id>
```

#### 1.2 Create Internet Gateway
```bash
# Create Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=apprunner-igw}]'

# Note the IGW ID and attach to VPC
export IGW_ID=<your-igw-id>
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
```

#### 1.3 Create Subnets
```bash
# Create public subnet in AZ-a
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1a}]'
export PUBLIC_SUBNET_ID=<your-public-subnet-id>

# Create private subnet in AZ-a
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1a}]'
export PRIVATE_SUBNET_ID=<your-private-subnet-id>

# Create private subnet in AZ-b (required for VPC Connector)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1b}]'
export PRIVATE_SUBNET_ID_2=<your-private-subnet-id-2>
```

#### 1.4 Create and Configure NAT Gateway
```bash
# Allocate Elastic IP for NAT Gateway
aws ec2 allocate-address --domain vpc --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=nat-gateway-eip}]'
export EIP_ALLOCATION_ID=<your-allocation-id>

# Create NAT Gateway in public subnet
aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID --allocation-id $EIP_ALLOCATION_ID --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=apprunner-nat-gw}]'
export NAT_GW_ID=<your-nat-gateway-id>
```

#### 1.5 Create Route Tables
```bash
# Create public route table
aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'
export PUBLIC_RT_ID=<your-public-rt-id>

# Create private route table
aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt}]'
export PRIVATE_RT_ID=<your-private-rt-id>

# Add routes
aws ec2 create-route --route-table-id $PUBLIC_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 create-route --route-table-id $PRIVATE_RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID

# Associate subnets with route tables
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUBLIC_RT_ID
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID --route-table-id $PRIVATE_RT_ID
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID_2 --route-table-id $PRIVATE_RT_ID
```

### Step 2: Launch EC2 Instance and Configure Nginx

#### 2.1 Create Security Group
```bash
# Create security group for EC2 instance
aws ec2 create-security-group --group-name ec2-nginx-sg --description "Security group for EC2 nginx server" --vpc-id $VPC_ID
export EC2_SG_ID=<your-security-group-id>

# Allow HTTP traffic from VPC CIDR
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --cidr 10.0.0.0/16

# Allow SSH access (optional, for troubleshooting)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 10.0.0.0/16
```

#### 2.2 Launch EC2 Instance
```bash
# Launch EC2 instance in private subnet
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t2.micro \
  --key-name <your-key-pair> \
  --security-group-ids $EC2_SG_ID \
  --subnet-id $PRIVATE_SUBNET_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=nginx-server}]' \
  --user-data file://install-nginx.sh

export EC2_INSTANCE_ID=<your-instance-id>
```

#### 2.3 Configure Nginx (Manual Steps)

If you need to manually configure nginx, connect to the instance and follow the detailed instructions in [ec2-nginx-deploy.md](./ec2-nginx-deploy.md).

**Key commands from the deployment guide:**
```bash
# Install nginx 1.24.0 (compatible with OpenSSL 3.0)
cd ~
wget http://nginx.org/download/nginx-1.24.0.tar.gz
tar -xzf nginx-1.24.0.tar.gz
cd nginx-1.24.0
./configure
make
sudo make install

# Add to PATH and start
echo 'export PATH=$PATH:/usr/local/nginx/sbin' >> ~/.bashrc
source ~/.bashrc
sudo nginx
```

#### 2.4 Get EC2 Private IP
```bash
# Get the private IP address of your EC2 instance
aws ec2 describe-instances --instance-ids $EC2_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text
export EC2_PRIVATE_IP=<your-ec2-private-ip>
```

### Step 3: Create AppRunner Service with VPC Connector

#### 3.1 Create VPC Connector
```bash
# Create VPC Connector for AppRunner
aws apprunner create-vpc-connector \
  --vpc-connector-name apprunner-vpc-connector \
  --subnets $PRIVATE_SUBNET_ID $PRIVATE_SUBNET_ID_2 \
  --security-groups $EC2_SG_ID

export VPC_CONNECTOR_ARN=<your-vpc-connector-arn>
```

#### 3.2 Create GitHub Connection
Since AppRunner only supports source code deployments from GitHub, you must create a GitHub connection:

```bash
# Create GitHub connection for source code repository
aws apprunner create-connection \
  --connection-name github-connection \
  --provider-type GITHUB

# Note the connection ARN from output
export CONNECTION_ARN=<your-connection-arn>

# Complete the GitHub authorization in the console
# Go to App Runner Console > Connections and complete the handshake
```

**Prerequisites**: 
- Fork this repository to your GitHub account
- Ensure you have access to the GitHub repository
- Complete the connection handshake in the AWS Console

#### 3.3 Create AppRunner Service
```bash
# Create AppRunner service with source code and VPC connectivity
aws apprunner create-service \
  --service-name apprunner-networking-demo \
  --source-configuration '{
    "CodeRepository": {
      "RepositoryUrl": "https://github.com/your-username/your-repo-name",
      "SourceCodeVersion": {
        "Type": "BRANCH",
        "Value": "main"
      },
      "CodeConfiguration": {
        "ConfigurationSource": "REPOSITORY"
      }
    },
    "AutoDeploymentsEnabled": true
  }' \
  --network-configuration '{
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "'$VPC_CONNECTOR_ARN'"
    }
  }'
```

**Important Notes:**
- Replace `your-username/your-repo-name` with your actual GitHub repository
- AppRunner only supports source code deployments from GitHub (not GitLab, Bitbucket, or S3)
- The service will use the `apprunner.yaml` file in the repository for build and runtime configuration
- You must complete the GitHub connection setup in the AWS Console before the service can deploy

### Step 4: Test VPC Connectivity

#### 4.1 Get AppRunner Service URL
```bash
# Get the AppRunner service URL
aws apprunner describe-service --service-arn <your-service-arn> --query 'Service.ServiceUrl' --output text
export APPRUNNER_URL=<your-apprunner-url>
```

#### 4.2 Test Connectivity

Once your AppRunner service is deployed with the Node.js application from this repository, you can test the VPC connectivity:

```bash
# Test basic connectivity
curl https://$APPRUNNER_URL/

# Test IP information endpoint
curl https://$APPRUNNER_URL/ip/8.8.8.8

# Test EC2 connectivity via private IP (key test for VPC connectivity)
curl https://$APPRUNNER_URL/curl-ec2/X.X.X.X
# Replace X.X.X.X with your EC2 instance's private IP
```

The `/curl-ec2/:privateIp` endpoint in the Node.js application will make an HTTP request to the EC2 instance's private IP address, demonstrating that AppRunner can reach private resources in your VPC through the VPC Connector. You should see the nginx welcome page HTML returned.

## Application Details

This repository contains a Node.js Express application with the following endpoints:

- `GET /` - Returns "Hello World!"
- `GET /ip/:ipAddress` - Fetches IP information using ipinfo.io
- `GET /curl-ec2/:privateIp` - Makes HTTP request to EC2 instance at specified private IP

The key endpoint for this tutorial is `/curl-ec2/:privateIp`, which demonstrates VPC connectivity by allowing the AppRunner service to communicate with EC2 instances in private subnets.

## Key Learning Points

1. **VPC Connector Requirements**: AppRunner VPC Connectors require at least 2 subnets in different AZs
2. **Security Groups**: Proper security group configuration is crucial for allowing traffic between AppRunner and EC2
3. **NAT Gateway**: Required for outbound internet access from private subnets
4. **Private IP Communication**: AppRunner can reach EC2 instances using their private IP addresses when VPC Connector is configured
5. **Network Isolation**: This setup provides secure, private communication without exposing EC2 instances to the internet

## Cleanup

To avoid ongoing charges, remember to delete the resources:

```bash
# Delete AppRunner service
aws apprunner delete-service --service-arn <your-service-arn>

# Delete VPC Connector
aws apprunner delete-vpc-connector --vpc-connector-arn $VPC_CONNECTOR_ARN

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids $EC2_INSTANCE_ID

# Delete NAT Gateway and release EIP
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
aws ec2 release-address --allocation-id $EIP_ALLOCATION_ID

# Delete VPC (this will delete associated subnets, route tables, etc.)
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Troubleshooting

- **AppRunner can't reach EC2**: Check security group rules and VPC Connector configuration
- **Nginx installation issues**: Refer to [ec2-nginx-deploy.md](./ec2-nginx-deploy.md) for detailed troubleshooting
- **VPC Connector creation fails**: Ensure subnets are in different AZs and have proper route table associations

## Additional Resources

- [AWS AppRunner VPC Connector Documentation](https://docs.aws.amazon.com/apprunner/latest/dg/network-vpc.html)
- [VPC Networking Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
