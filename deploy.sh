#!/bin/bash

echo "🔍 Fetching AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

NAV_REPO_NAME="mystery-island-navigation"
CHAT_REPO_NAME="mystery-island-chatbot"

NAV_ECR_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$NAV_REPO_NAME"
CHAT_ECR_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$CHAT_REPO_NAME"

echo "✅ Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "🐳 Building navigation Docker image..."
cd navigation-app || exit
docker build -t $NAV_REPO_NAME .
docker tag $NAV_REPO_NAME:latest $NAV_ECR_URL
docker push $NAV_ECR_URL
cd ..

echo "🤖 Building chatbot Docker image..."
cd chatbot || exit
docker build -t $CHAT_REPO_NAME .
docker tag $CHAT_REPO_NAME:latest $CHAT_ECR_URL
docker push $CHAT_ECR_URL
cd ..

echo "📦 Deploying infrastructure with Terraform..."
cd Deploy || exit
terraform init -input=false
terraform apply -auto-approve
cd ..

echo "🎉 Full deployment complete! Both navigation and chatbot containers are deployed."
