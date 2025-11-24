#!/bin/bash

# Script to package the application for deployment to S3
# Usage: ./package-for-deployment.sh [s3-bucket-name]

set -e

BUCKET_NAME=${1:-"your-app-bucket"}
APP_NAME="product-catalog"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="${APP_NAME}-${TIMESTAMP}.tar.gz"

echo "Packaging application for deployment..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$APP_NAME"

mkdir -p $PACKAGE_DIR

# Copy application files
echo "Copying application files..."
cp -r main.py crud.py database.py config.py requirements.txt $PACKAGE_DIR/

# Create .gitignore for deployment (exclude .env and database files)
cat > $PACKAGE_DIR/.gitignore << EOF
.env
*.db
*.db-journal
__pycache__/
*.pyc
*.pyo
venv/
.venv/
EOF

# Create deployment README
cat > $PACKAGE_DIR/DEPLOYMENT.md << EOF
# Deployment Package

This package contains the Product Catalog FastAPI application.

## Files Included
- main.py - FastAPI application
- crud.py - CRUD operations
- database.py - Database configuration
- config.py - Settings management
- requirements.txt - Python dependencies

## Setup
1. Extract this package to /opt/product-catalog
2. Run the user-data script or follow manual setup instructions
3. Configure environment variables in .env file
EOF

# Create tarball
cd $TEMP_DIR
tar -czf $PACKAGE_NAME $APP_NAME

# Get package size
PACKAGE_SIZE=$(du -h $PACKAGE_NAME | cut -f1)

echo "Package created: $PACKAGE_NAME ($PACKAGE_SIZE)"
echo "Location: $TEMP_DIR/$PACKAGE_NAME"

# Optionally upload to S3
read -p "Upload to S3 bucket '$BUCKET_NAME'? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v aws &> /dev/null; then
        S3_KEY="deployments/$PACKAGE_NAME"
        echo "Uploading to s3://$BUCKET_NAME/$S3_KEY..."
        aws s3 cp $TEMP_DIR/$PACKAGE_NAME s3://$BUCKET_NAME/$S3_KEY
        echo "Upload complete!"
        echo "S3 Location: s3://$BUCKET_NAME/$S3_KEY"
        echo ""
        echo "Update your user-data script with:"
        echo "  S3_BUCKET=$BUCKET_NAME"
        echo "  S3_KEY=$S3_KEY"
    else
        echo "AWS CLI not found. Please install it to upload to S3."
        echo "Or manually upload: aws s3 cp $TEMP_DIR/$PACKAGE_NAME s3://$BUCKET_NAME/deployments/"
    fi
else
    echo "Package saved locally. Upload manually when ready:"
    echo "  aws s3 cp $TEMP_DIR/$PACKAGE_NAME s3://$BUCKET_NAME/deployments/"
fi

echo ""
echo "Package location: $TEMP_DIR/$PACKAGE_NAME"
echo "To extract: tar -xzf $TEMP_DIR/$PACKAGE_NAME"

