1. How to Run

Save this script as deploy-irsa.sh

Make it executable:

chmod +x deploy-irsa.sh

2. Run it:
./deploy-irsa.sh

#######################################################################


#!/bin/bash

# ====== CONFIGURATION ======
STACK_NAME="eks-irsa-role"
TEMPLATE_FILE="eks-irsa.yaml"

# ====== STEP 1: Validate Template ======
echo "🔍 Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://$TEMPLATE_FILE

if [ $? -ne 0 ]; then
  echo "❌ Template validation failed. Exiting."
  exit 1
fi

# ====== STEP 2: Check if stack already exists ======
echo "🔎 Checking if stack $STACK_NAME exists..."
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME 2>/dev/null)

if [ -z "$STACK_EXISTS" ]; then
  echo "🚀 Creating new stack: $STACK_NAME"
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

  echo "⏳ Waiting for stack creation to complete..."
  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
else
  echo "🔄 Updating existing stack: $STACK_NAME"
  aws cloudformation update-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM || {
      echo "⚠️ No updates to be performed."
      exit 0
  }

  echo "⏳ Waiting for stack update to complete..."
  aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
fi

# ====== STEP 3: Get Stack Outputs ======
echo "✅ Stack deployment completed. Fetching outputs..."
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs" \
  --output table
