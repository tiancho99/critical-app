#!/bin/bash

# Minimal User Data Script for AWS Auto Scaling Group
# Simple setup for quick deployment

set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Setting up Product Catalog application..."

# Update and install Python
yum update -y
yum install -y python3 python3-pip

# Create app directory
APP_DIR="/opt/product-catalog"
mkdir -p $APP_DIR
cd $APP_DIR

# Note: Application files should be deployed via:
# - S3 + User Data
# - CodeDeploy
# - Git clone
# - EFS mount
# For this example, we assume files are already present

# Create virtual environment and install dependencies
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

# Create .env file (or use environment variables)
cat > .env << EOF
DATABASE_URL=${DATABASE_URL:-sqlite:///./products.db}
DB_ECHO=False
API_TITLE=Product Catalog API
API_VERSION=1.0.0
DEFAULT_SKIP=0
DEFAULT_LIMIT=100
EOF

# Create systemd service
cat > /etc/systemd/system/product-catalog.service << EOF
[Unit]
Description=Product Catalog API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
EnvironmentFile=$APP_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable product-catalog.service
systemctl start product-catalog.service

echo "Setup complete!"

