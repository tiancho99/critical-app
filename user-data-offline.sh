#!/bin/bash
exec > /var/log/user-data.log 2>&1
echo "Starting user-data script at $(date)"

# Assume /home/ec2-user/AWS and .venv already exist from the AMI

cat > /etc/systemd/system/fastapi.service << 'EOF'
[Unit]
Description=FastAPI Application
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/AWS
ExecStart=/home/ec2-user/AWS/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi

chown -R ec2-user:ec2-user /home/ec2-user/AWS
echo "User data script completed at $(date)"
