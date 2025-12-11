# AWS AppRunner VPC Networking Tutorial

This tutorial demonstrates how to set up AWS AppRunner with VPC connectivity to access private EC2 instances using the AWS Management Console. You'll learn how to create a complete networking setup that allows an AppRunner service to communicate with EC2 instances in private subnets using VPC Connectors.

## Architecture Overview

The tutorial creates:
- A VPC with public and private subnets across multiple AZs
- A NAT Gateway for outbound internet access from private subnets
- An EC2 instance in a private subnet running nginx
- An AppRunner service with VPC Connector for private network access
- A Node.js application that demonstrates connectivity by making HTTP requests to the EC2 instance's private IP

## Prerequisites

- AWS account with appropriate permissions
- Basic understanding of VPC networking concepts
- Node.js application (provided in this repository)

## Tutorial Options

- **Console Tutorial**: Follow the steps below using the AWS Management Console
- **CLI Tutorial**: For AWS CLI commands, see [README-CLI.md](./README-CLI.md)

## Console Tutorial Steps

### Step 1: Create VPC with Public/Private Setup and NAT Gateway

#### 1.1 Create the VPC
1. Navigate to the **VPC Console** in AWS Management Console
2. Click **Create VPC**
3. Choose **VPC and more** for guided setup
4. Configure the following:
   - **Name tag auto-generation**: `apprunner`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **Number of Availability Zones**: `2`
   - **Number of public subnets**: `1`
   - **Number of private subnets**: `2`
   - **NAT gateways**: `In 1 AZ`
   - **VPC endpoints**: `None`
5. Click **Create VPC**

This will automatically create:
- VPC with CIDR 10.0.0.0/16
- Internet Gateway attached to VPC
- Public subnet (10.0.0.0/24) in us-east-1a
- Private subnet (10.0.1.0/24) in us-east-1a
- Private subnet (10.0.2.0/24) in us-east-1b
- NAT Gateway in the public subnet
- Route tables with appropriate routes
- Elastic IP for NAT Gateway

#### 1.2 Note the Resource IDs
After creation, note down the following IDs from the VPC dashboard:
- **VPC ID**: `vpc-xxxxxxxxx`
- **Public Subnet ID**: `subnet-xxxxxxxxx` (us-east-1a)
- **Private Subnet ID 1**: `subnet-xxxxxxxxx` (us-east-1a)
- **Private Subnet ID 2**: `subnet-xxxxxxxxx` (us-east-1b)

### Step 2: Launch EC2 Instance and Configure Nginx

#### 2.1 Create Security Group
1. In the **VPC Console**, navigate to **Security Groups**
2. Click **Create security group**
3. Configure:
   - **Security group name**: `ec2-nginx-sg`
   - **Description**: `Security group for EC2 nginx server`
   - **VPC**: Select your created VPC (`apprunner-vpc`)
4. Add **Inbound rules**:
   - **Rule 1**: Type: `HTTP`, Port: `80`, Source: `10.0.0.0/16` (VPC CIDR)
   - **Rule 2**: Type: `SSH`, Port: `22`, Source: `10.0.0.0/16` (optional, for troubleshooting)
5. Click **Create security group**
6. Note the **Security Group ID**: `sg-xxxxxxxxx`

#### 2.2 Launch EC2 Instance
1. Navigate to **EC2 Console**
2. Click **Launch Instance**
3. Configure:
   - **Name**: `nginx-server`
   - **AMI**: `Amazon Linux 2023 AMI` (latest)
   - **Instance type**: `t2.micro`
   - **Key pair**: Select your existing key pair or create new one
   - **Network settings**:
     - **VPC**: Select your created VPC
     - **Subnet**: Select the **private subnet in us-east-1a**
     - **Auto-assign public IP**: `Disable`
     - **Security groups**: Select `ec2-nginx-sg`
4. In **Advanced details** > **User data**, paste the contents of `install-nginx.sh`:
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y gcc pcre-devel zlib-devel openssl-devel wget make
   cd /home/ec2-user
   wget http://nginx.org/download/nginx-1.24.0.tar.gz
   tar -xzf nginx-1.24.0.tar.gz
   cd nginx-1.24.0
   ./configure
   make
   make install
   echo 'export PATH=$PATH:/usr/local/nginx/sbin' >> /home/ec2-user/.bashrc
   /usr/local/nginx/sbin/nginx
   ```
5. Click **Launch instance**

#### 2.3 Get EC2 Private IP
1. In **EC2 Console**, select your `nginx-server` instance
2. Note the **Private IPv4 address** from the instance details
3. Save this IP address: `10.0.1.xxx`

#### 2.4 Verify Nginx Installation
The nginx installation will happen automatically via the user data script. The instance will:
- Download and compile nginx 1.24.0 (compatible with OpenSSL 3.0)
- Install it to `/usr/local/nginx/`
- Start the nginx service

For manual configuration or troubleshooting, refer to [ec2-nginx-deploy.md](./ec2-nginx-deploy.md).

### Step 3: Create AppRunner Service with VPC Connector

#### 3.1 Create VPC Connector
1. Navigate to **App Runner Console**
2. In the left sidebar, click **VPC connectors**
3. Click **Create VPC connector**
4. Configure:
   - **VPC connector name**: `apprunner-vpc-connector`
   - **VPC**: Select your created VPC
   - **Subnets**: Select both private subnets (us-east-1a and us-east-1b)
   - **Security groups**: Select `ec2-nginx-sg`
5. Click **Create VPC connector**
6. Wait for the connector status to become **Active** (takes 2-3 minutes)

#### 3.2 Prepare GitHub Repository
This tutorial uses the Node.js application in this repository, which includes an `apprunner.yaml` configuration file. Since AppRunner only supports source code deployments from GitHub and BitBucket:

1. **Fork this repository** to your GitHub account
2. Ensure the repository is **public** or set up GitHub connection for private repos
3. Note your GitHub repository URL: `https://github.com/your-username/repository-name`

**Important**: AppRunner source code deployments only work with GitHub and BitBucket repositories. Other git providers or S3 are not supported for source code deployments.

#### 3.3 Create AppRunner Service
1. In **App Runner Console**, click **Create service**
2. **Step 1 - Source**:
   - **Repository type**: `Source code repository`
   - **Provider**: `GitHub` (only option for source code)
   - **Add new**: Click to connect your GitHub account (if first time)
   - **Repository**: Select your forked repository
   - **Branch**: `main` or `master`
   - **Deployment trigger**: `Automatic` (deploys on code changes)
   - Click **Next**
3. **Step 2 - Build**:
   - **Configuration file**: `Use a configuration file` (apprunner.yaml will be detected)
   - The system will show the detected `apprunner.yaml` configuration
   - Click **Next**
4. **Step 3 - Service**:
   - **Service name**: `apprunner-networking-demo`
   - **Virtual CPU**: `0.25 vCPU` (or as specified in apprunner.yaml)
   - **Memory**: `0.5 GB` (or as specified in apprunner.yaml)
   - Click **Next**
5. **Step 4 - Networking**:
   - **Outgoing network traffic**: `VPC`
   - **VPC connector**: Select `apprunner-vpc-connector`
   - Click **Next**
6. **Step 5 - Review**: Review settings and click **Create & deploy**
7. Wait for deployment to complete (takes 5-8 minutes for source code builds)

#### 3.4 Note the Service URL
Once deployed, note the **Default domain** URL from the service overview page:
- Format: `https://xxxxxxxxxx.us-east-1.awsapprunner.com`

### Step 4: Test VPC Connectivity

#### 4.1 Test Basic AppRunner Connectivity
1. Open your browser and navigate to your AppRunner service URL
2. You should see the hello-app-runner welcome page
3. This confirms the AppRunner service is running correctly

#### 4.2 Test VPC Connectivity with Node.js Application

Since you've deployed the Node.js application from this repository, you can now test the VPC connectivity:

**Test the Application Endpoints**:
1. **Basic connectivity**: `https://your-apprunner-url.awsapprunner.com/`
   - Should return "Hello World!"
2. **IP information**: `https://your-apprunner-url.awsapprunner.com/ip/8.8.8.8`
   - Tests external API calls and returns IP information
3. **VPC connectivity**: `https://your-apprunner-url.awsapprunner.com/curl-ec2/X.X.X.X`
   - Replace `X.X.X.X` with your EC2 instance's private IP
   - This endpoint makes an HTTP request to the EC2 instance's private IP
   - Should return the nginx welcome page HTML

#### 4.3 Expected Results

When the Node.js application is deployed and you access the `/curl-ec2/:privateIp` endpoint:

1. **Success Response**: You'll see the nginx welcome page HTML returned from the EC2 instance
2. **This proves**: AppRunner can reach private EC2 instances through the VPC Connector
3. **Network Flow**: 
   - Internet → AppRunner Service
   - AppRunner Service → VPC Connector → Private Subnet → EC2 Instance
   - EC2 Instance → nginx response → back through the same path

#### 4.4 Troubleshooting Connectivity

If connectivity fails:
1. **Check Security Groups**: Ensure `ec2-nginx-sg` allows HTTP (port 80) from VPC CIDR
2. **Verify nginx**: Connect to EC2 via Session Manager and check `sudo nginx -t`
3. **Check VPC Connector**: Ensure it's in "Active" status
4. **Verify Subnets**: Confirm VPC Connector uses both private subnets
5. **Route Tables**: Ensure private subnets route to NAT Gateway for outbound access

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

To avoid ongoing charges, delete the resources in this order:

### 1. Delete AppRunner Service
1. Go to **App Runner Console**
2. Select your service `apprunner-networking-demo`
3. Click **Actions** → **Delete**
4. Type the service name to confirm and click **Delete**

### 2. Delete VPC Connector
1. In **App Runner Console**, go to **VPC connectors**
2. Select `apprunner-vpc-connector`
3. Click **Delete**
4. Confirm deletion

### 3. Terminate EC2 Instance
1. Go to **EC2 Console**
2. Select the `nginx-server` instance
3. Click **Instance state** → **Terminate instance**
4. Confirm termination

### 4. Delete VPC and Associated Resources
1. Go to **VPC Console**
2. Select your VPC (`apprunner-vpc`)
3. Click **Actions** → **Delete VPC**
4. This will automatically delete:
   - Subnets
   - Route tables
   - Internet Gateway
   - NAT Gateway
   - Elastic IP
   - Security Groups

**Note**: The VPC deletion will fail if any resources are still using it. Ensure all AppRunner services and EC2 instances are deleted first.

## Troubleshooting

- **AppRunner can't reach EC2**: Check security group rules and VPC Connector configuration
- **Nginx installation issues**: Refer to [ec2-nginx-deploy.md](./ec2-nginx-deploy.md) for detailed troubleshooting
- **VPC Connector creation fails**: Ensure subnets are in different AZs and have proper route table associations

## Additional Resources

- [AWS AppRunner VPC Connector Documentation](https://docs.aws.amazon.com/apprunner/latest/dg/network-vpc.html)
- [VPC Networking Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
