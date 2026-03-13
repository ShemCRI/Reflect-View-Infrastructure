#!/bin/bash

# Script to access the Provisioning UI via SSM port forwarding

INSTANCE_ID="i-040c9ba3f55a32497"
PROFILE="rv-shared"
REGION="us-east-1"
LOCAL_PORT="3000"
REMOTE_PORT="3000"

echo "🚀 Starting SSM port forwarding to Provisioning UI..."
echo ""
echo "Instance: $INSTANCE_ID"
echo "Local URL: http://localhost:$LOCAL_PORT"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo ""

# Check if SSO session is valid
if ! aws sts get-caller-identity --profile $PROFILE &>/dev/null; then
    echo "⚠️  AWS SSO session expired or not logged in"
    echo "Running: aws sso login --profile $PROFILE"
    aws sso login --profile $PROFILE
fi

# Start port forwarding
aws ssm start-session \
    --target $INSTANCE_ID \
    --document-name AWS-StartPortForwardingSession \
    --parameters "{\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --profile $PROFILE \
    --region $REGION
