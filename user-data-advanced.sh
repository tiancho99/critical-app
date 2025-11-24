#!/bin/bash

# Advanced User Data Script for AWS Auto Scaling Group
# Uses AWS Systems Manager Parameter Store for configuration
# Supports RDS database connection

set -e  # Exit on error

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting advanced user-data script execution..."

# Install AWS CLI and jq (if not already installed)
yum update -y
yum install -y python3 python3-pip git jq

# Install AWS CLI v2 (if needed)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
fi

# Get instance region
INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export AWS_DEFAULT_REGION=$INSTANCE_REGION

# Function to get parameter from SSM Parameter Store
get_ssm_parameter() {
    local param_name=$1
    local default_value=$2
    aws ssm get-parameter --name "$param_name" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$default_value"
}

# Get configuration from SSM Parameter Store (with defaults)
# Parameter names should be: /product-catalog/DATABASE_URL, /product-catalog/DB_ECHO, etc.
DATABASE_URL=$(get_ssm_parameter "/product-catalog/DATABASE_URL" "sqlite:///./products.db")
DB_ECHO=$(get_ssm_parameter "/product-catalog/DB_ECHO" "False")
API_TITLE=$(get_ssm_parameter "/product-catalog/API_TITLE" "Product Catalog API")
API_VERSION=$(get_ssm_parameter "/product-catalog/API_VERSION" "1.0.0")
DEFAULT_SKIP=$(get_ssm_parameter "/product-catalog/DEFAULT_SKIP" "0")
DEFAULT_LIMIT=$(get_ssm_parameter "/product-catalog/DEFAULT_LIMIT" "100")

# Create application directory
APP_DIR="/opt/product-catalog"
mkdir -p $APP_DIR
cd $APP_DIR

# Download application from S3 (recommended approach)
# Replace with your S3 bucket and path
S3_BUCKET="${S3_BUCKET:-your-app-bucket}"
S3_KEY="${S3_KEY:-product-catalog/app.tar.gz}"

if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "your-app-bucket" ]; then
    echo "Downloading application from S3..."
    aws s3 cp s3://$S3_BUCKET/$S3_KEY $APP_DIR/app.tar.gz
    tar -xzf $APP_DIR/app.tar.gz -C $APP_DIR
    rm $APP_DIR/app.tar.gz
fi

# Alternative: Clone from Git
# git clone https://github.com/your-username/product-catalog.git $APP_DIR

# Create virtual environment
python3 -m venv $APP_DIR/venv
source $APP_DIR/venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install application dependencies
if [ -f "$APP_DIR/requirements.txt" ]; then
    pip install -r $APP_DIR/requirements.txt
else
    echo "Error: requirements.txt not found"
    exit 1
fi

# Create .env file
cat > $APP_DIR/.env << EOF
# Database Configuration
DATABASE_URL=$DATABASE_URL
DB_ECHO=$DB_ECHO

# API Settings
API_TITLE=$API_TITLE
API_VERSION=$API_VERSION

# Pagination Defaults
DEFAULT_SKIP=$DEFAULT_SKIP
DEFAULT_LIMIT=$DEFAULT_LIMIT
EOF

# Set proper permissions
chown -R ec2-user:ec2-user $APP_DIR
chmod +x $APP_DIR/*.py 2>/dev/null || true

# Create systemd service file
cat > /etc/systemd/system/product-catalog.service << EOF
[Unit]
Description=FastAPI Product Catalog Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=$APP_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always
RestartSec=10

# Environment variables
EnvironmentFile=$APP_DIR/.env

# Resource limits
LimitNOFILE=65536

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=product-catalog

[Install]
WantedBy=multi-user.target
EOF

# Create log rotation configuration
cat > /etc/logrotate.d/product-catalog << EOF
/var/log/product-catalog/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 ec2-user ec2-user
    sharedscripts
}
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable product-catalog.service
systemctl start product-catalog.service

# Wait for service to start
sleep 10

# Health check
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "Health check passed!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for service to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

# Check final service status
if systemctl is-active --quiet product-catalog.service; then
    echo "Product Catalog service started successfully"
    systemctl status product-catalog.service --no-pager
else
    echo "ERROR: Product Catalog service failed to start"
    systemctl status product-catalog.service --no-pager
    journalctl -u product-catalog.service --no-pager -n 50
    exit 1
fi

# Create CloudWatch log group (optional)
LOG_GROUP_NAME="/aws/ec2/product-catalog"
aws logs create-log-group --log-group-name $LOG_GROUP_NAME 2>/dev/null || true

# Send initial status to CloudWatch (optional)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws cloudwatch put-metric-data \
    --namespace "ProductCatalog" \
    --metric-data MetricName=InstanceStarted,Value=1,Unit=Count \
    --dimensions InstanceId=$INSTANCE_ID 2>/dev/null || true

echo "User-data script completed successfully"
echo "Application is running at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"

