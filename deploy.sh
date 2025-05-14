#!/bin/bash

echo "🔍 Fetching AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
REPO_NAME="mystery-island-navigation"
ECR_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

echo "📦 Deploying infrastructure with Terraform..."
cd Deploy || exit
terraform init -input=false
terraform apply -auto-approve
cd ..

echo "✅ Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

echo "🐳 Building Docker image..."
cd navigation-app || exit
docker build -t $REPO_NAME .

echo "🏷️ Tagging Docker image for ECR..."
docker tag $REPO_NAME:latest $ECR_URL

echo "📤 Pushing image to ECR..."
docker push $ECR_URL
cd ..

echo "🎉 Deployment complete!"
