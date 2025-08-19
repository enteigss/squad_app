#!/bin/bash

# Twilio Configuration Helper Script
# This script helps you configure Twilio credentials for SMS invites

set -e

echo "📱 Twilio SMS Configuration for Squad App"
echo "========================================"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if logged into Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged into Firebase. Please login first:"
    echo "firebase login"
    exit 1
fi

echo ""
echo "🔍 To find your Twilio credentials:"
echo "   1. Go to https://console.twilio.com"
echo "   2. Navigate to Account → Account Info"
echo "   3. Copy Account SID and Auth Token"
echo "   4. Go to Phone Numbers → Manage → Active numbers"
echo "   5. Copy your SMS-enabled phone number"
echo ""

# Get Twilio Account SID
read -p "Enter your Twilio Account SID: " ACCOUNT_SID
if [ -z "$ACCOUNT_SID" ]; then
    echo "❌ Account SID is required"
    exit 1
fi

# Get Twilio Auth Token
read -s -p "Enter your Twilio Auth Token: " AUTH_TOKEN
echo ""
if [ -z "$AUTH_TOKEN" ]; then
    echo "❌ Auth Token is required"
    exit 1
fi

# Get Twilio Phone Number
echo ""
echo "📞 Enter your Twilio phone number in E.164 format (e.g., +1234567890)"
read -p "Twilio Phone Number: " PHONE_NUMBER
if [ -z "$PHONE_NUMBER" ]; then
    echo "❌ Phone number is required"
    exit 1
fi

# Validate phone number format
if [[ ! $PHONE_NUMBER =~ ^\+[1-9]\d{1,14}$ ]]; then
    echo "⚠️  Warning: Phone number should be in E.164 format (+1234567890)"
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "🔧 Configuring Firebase Functions environment variables..."

# Set Firebase Functions config
firebase functions:config:set \
    twilio.account_sid="$ACCOUNT_SID" \
    twilio.auth_token="$AUTH_TOKEN" \
    twilio.phone_number="$PHONE_NUMBER"

echo ""
echo "✅ Twilio configuration complete!"
echo ""
echo "📋 Configuration summary:"
echo "   Account SID: $ACCOUNT_SID"
echo "   Auth Token: ${AUTH_TOKEN:0:8}... (hidden)"
echo "   Phone Number: $PHONE_NUMBER"
echo ""
echo "🚀 Next steps:"
echo "   1. Run the deployment script: ./deploy-sms-invites.sh"
echo "   2. Test SMS sending functionality"
echo "   3. Monitor costs in Twilio Console"
echo ""
echo "💰 Cost information:"
echo "   - US/Canada SMS: ~$0.0075 per message"
echo "   - International SMS: $0.01-$0.05 per message"
echo "   - Set spending limits in Twilio Console for cost control"
echo ""
echo "📖 For detailed setup instructions, see SMS_INVITE_SETUP.md"