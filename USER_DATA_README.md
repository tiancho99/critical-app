# AWS Auto Scaling Group User Data Scripts

This directory contains user data scripts for deploying the FastAPI Product Catalog application on AWS EC2 instances in an Auto Scaling Group.

## Available Scripts

### 1. `user-data-minimal.sh` - Simple Setup
- Basic installation and service setup
- Good for development/testing
- Minimal dependencies

### 2. `user-data.sh` - Standard Setup
- Complete setup with logging
- Systemd service configuration
- Health checks
- Recommended for most use cases

### 3. `user-data-advanced.sh` - Production Setup
- AWS Systems Manager Parameter Store integration
- S3 deployment support
- CloudWatch logging
- Multiple workers for better performance
- Production-ready configuration

## Prerequisites

Before using these scripts, ensure:

1. **Application Files**: Your application files need to be available to the EC2 instances. Options:
   - **S3 Bucket**: Upload your application to S3 and configure the script to download it
   - **Git Repository**: Clone from a Git repository
   - **CodeDeploy**: Use AWS CodeDeploy for deployment
   - **EFS**: Mount application files from EFS

2. **IAM Permissions**: EC2 instances need appropriate IAM roles:
   - For S3: `AmazonS3ReadOnlyAccess` or custom policy
   - For SSM Parameter Store: `AmazonSSMReadOnlyAccess`
   - For CloudWatch: `CloudWatchLogsFullAccess` (if using advanced script)

3. **Security Groups**: Configure security groups to allow:
   - Port 8000 (or your chosen port) from Application Load Balancer
   - SSH access (port 22) for debugging

## Usage

### Option 1: Via AWS Console

1. Go to EC2 → Launch Templates or Auto Scaling Groups
2. Edit your launch template/configuration
3. In the "Advanced details" section, paste the user data script
4. Save and create/update instances

### Option 2: Via AWS CLI

```bash
# Create launch template with user data
aws ec2 create-launch-template \
    --launch-template-name product-catalog-template \
    --launch-template-data file://user-data.sh
```

### Option 3: Via Terraform

```hcl
resource "aws_launch_template" "product_catalog" {
  name_prefix   = "product-catalog-"
  image_id      = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t3.micro"
  
  user_data = base64encode(file("${path.module}/user-data.sh"))
  
  vpc_security_group_ids = [aws_security_group.app.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }
}
```

### Option 4: Via CloudFormation

```yaml
LaunchTemplate:
  Type: AWS::EC2::LaunchTemplate
  Properties:
    LaunchTemplateName: product-catalog-template
    LaunchTemplateData:
      ImageId: ami-0c55b159cbfafe1f0
      InstanceType: t3.micro
      UserData: !Base64 |
        #!/bin/bash
        # ... paste user-data.sh content here ...
```

## Configuration

### Environment Variables

The scripts support environment variables that can be set in the Auto Scaling Group or Launch Template:

- `DATABASE_URL`: Database connection string (default: `sqlite:///./products.db`)
- `DB_ECHO`: Enable SQL query logging (default: `False`)
- `API_TITLE`: API title (default: `Product Catalog API`)
- `API_VERSION`: API version (default: `1.0.0`)
- `DEFAULT_SKIP`: Default pagination skip (default: `0`)
- `DEFAULT_LIMIT`: Default pagination limit (default: `100`)

### Using AWS Systems Manager Parameter Store (Advanced Script)

1. Create parameters in Parameter Store:
```bash
aws ssm put-parameter --name "/product-catalog/DATABASE_URL" \
    --value "postgresql://user:pass@rds-endpoint:5432/dbname" \
    --type "SecureString"

aws ssm put-parameter --name "/product-catalog/DB_ECHO" \
    --value "False" \
    --type "String"
```

2. Ensure EC2 instances have IAM permissions to read from Parameter Store

### Database Configuration

For production, consider using:
- **Amazon RDS**: PostgreSQL or MySQL
- **Amazon RDS Proxy**: For connection pooling
- **Amazon DynamoDB**: For NoSQL needs

Update `DATABASE_URL` accordingly:
```
# PostgreSQL
DATABASE_URL=postgresql://user:password@rds-endpoint:5432/dbname

# MySQL
DATABASE_URL=mysql+pymysql://user:password@rds-endpoint:3306/dbname
```

## Application Load Balancer Integration

Configure your Application Load Balancer (ALB) to:
1. Target Group: Point to port 8000
2. Health Check: Use `/health` endpoint
3. Listener: Forward traffic to target group

## Monitoring

### View Logs

```bash
# Systemd service logs
sudo journalctl -u product-catalog.service -f

# User data execution log
sudo cat /var/log/user-data.log

# Application logs (if configured)
sudo tail -f /var/log/product-catalog/*.log
```

### Health Checks

The application exposes a `/health` endpoint that returns:
```json
{"status": "OK"}
```

Configure ALB health checks to use this endpoint.

## Troubleshooting

1. **Service not starting**: Check logs with `sudo journalctl -u product-catalog.service`
2. **Application files missing**: Ensure files are deployed via S3, Git, or CodeDeploy
3. **Database connection issues**: Verify `DATABASE_URL` and network connectivity
4. **Permission errors**: Check file ownership and permissions in `/opt/product-catalog`

## Security Best Practices

1. **Use IAM Roles**: Don't hardcode AWS credentials
2. **Secrets Management**: Use AWS Secrets Manager or Parameter Store for sensitive data
3. **Security Groups**: Restrict access to necessary ports only
4. **Database**: Use RDS with encryption and VPC security groups
5. **HTTPS**: Use Application Load Balancer with SSL/TLS certificates

## Next Steps

1. Set up Application Load Balancer
2. Configure Auto Scaling policies
3. Set up CloudWatch alarms
4. Configure backup and disaster recovery
5. Set up CI/CD pipeline for automated deployments

