#!/bin/bash

# User Data Script for AWS Auto Scaling Group
# This script sets up and runs the FastAPI Product Catalog application

set -e  # Exit on error

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user-data script execution..."

# Update system packages
yum update -y

# Install Python 3.9+ and pip
yum install -y python3 python3-pip git

# Install Python 3.9+ if not available (Amazon Linux 2)
if ! command -v python3.9 &> /dev/null; then
    yum install -y python3.9 python3.9-pip || yum install -y python39 python39-pip
fi

# Create application directory
APP_DIR="/opt/product-catalog"
mkdir -p $APP_DIR
cd $APP_DIR

# Download application files (assuming they're in S3 or Git)
# Option 1: If using S3, uncomment and configure:
# aws s3 cp s3://your-bucket/product-catalog/ $APP_DIR --recursive

# Option 2: If using Git, uncomment and configure:
# git clone https://github.com/your-username/product-catalog.git .
# Or use CodeDeploy, CodePipeline, etc.

# For now, we'll assume files are already in place via deployment
# Create a placeholder structure if needed
if [ ! -f "$APP_DIR/main.py" ]; then
    echo "Warning: Application files not found. Please ensure files are deployed."
fi

# Create virtual environment
python3 -m venv $APP_DIR/venv
source $APP_DIR/venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install application dependencies
if [ -f "$APP_DIR/requirements.txt" ]; then
    pip install -r $APP_DIR/requirements.txt
else
    echo "Warning: requirements.txt not found"
fi

# Create .env file with environment variables
# You can also use AWS Systems Manager Parameter Store or Secrets Manager
cat > $APP_DIR/.env << EOF
# Database Configuration
DATABASE_URL=${DATABASE_URL:-sqlite:///./products.db}
DB_ECHO=${DB_ECHO:-False}

# API Settings
API_TITLE=${API_TITLE:-Product Catalog API}
API_VERSION=${API_VERSION:-1.0.0}

# Pagination Defaults
DEFAULT_SKIP=${DEFAULT_SKIP:-0}
DEFAULT_LIMIT=${DEFAULT_LIMIT:-100}
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
ExecStart=$APP_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

# Environment variables
EnvironmentFile=$APP_DIR/.env

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=product-catalog

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable product-catalog.service
systemctl start product-catalog.service

# Wait a moment for service to start
sleep 5

# Check service status
if systemctl is-active --quiet product-catalog.service; then
    echo "Product Catalog service started successfully"
else
    echo "Warning: Product Catalog service failed to start"
    systemctl status product-catalog.service
fi

# Configure firewall (if needed)
# Allow HTTP traffic on port 8000
# Note: In AWS, use Security Groups instead of local firewall
# firewall-cmd --permanent --add-port=8000/tcp || true
# firewall-cmd --reload || true

# Health check script
cat > /usr/local/bin/health-check.sh << 'HEALTH_EOF'
#!/bin/bash
curl -f http://localhost:8000/health || exit 1
HEALTH_EOF

chmod +x /usr/local/bin/health-check.sh

echo "User-data script completed successfully"
echo "Application should be running at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"

