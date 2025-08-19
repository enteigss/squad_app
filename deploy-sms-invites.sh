#!/bin/bash

# SMS Invite System Deployment Script
# This script helps deploy the complete SMS invite system

set -e

echo "🚀 Squad App SMS Invite System Deployment"
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

# Get current project
PROJECT_ID=$(firebase use --quiet)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No Firebase project selected. Please select a project:"
    echo "firebase use --add"
    exit 1
fi

echo "📋 Current Firebase project: $PROJECT_ID"
echo ""

# Check for required environment variables
echo "🔍 Checking Twilio configuration..."
TWILIO_SID=$(firebase functions:config:get twilio.account_sid 2>/dev/null || echo "")
TWILIO_TOKEN=$(firebase functions:config:get twilio.auth_token 2>/dev/null || echo "")
TWILIO_PHONE=$(firebase functions:config:get twilio.phone_number 2>/dev/null || echo "")

if [ -z "$TWILIO_SID" ] || [ -z "$TWILIO_TOKEN" ] || [ -z "$TWILIO_PHONE" ]; then
    echo "⚠️  Twilio configuration missing. Please set environment variables:"
    echo ""
    echo "firebase functions:config:set \\"
    echo "  twilio.account_sid=\"your_account_sid\" \\"
    echo "  twilio.auth_token=\"your_auth_token\" \\"
    echo "  twilio.phone_number=\"+1234567890\""
    echo ""
    read -p "Continue without Twilio config? (y/N): " continue_without_twilio
    if [[ ! $continue_without_twilio =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Twilio configuration found"
fi

echo ""

# Install Function dependencies
echo "📦 Installing Cloud Functions dependencies..."
cd functions
if [ ! -d "node_modules" ]; then
    npm install
else
    echo "✅ Dependencies already installed"
fi

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

cd ..

# Deploy Functions
echo "☁️  Deploying Cloud Functions..."
firebase deploy --only functions

echo ""

# Deploy Firestore rules
echo "🔒 Deploying Firestore security rules..."
firebase deploy --only firestore:rules

echo ""

# Deploy Hosting (if firebase.json is configured)
if grep -q "hosting" firebase.json 2>/dev/null; then
    echo "🌐 Deploying Firebase Hosting..."
    firebase deploy --only hosting
else
    echo "⚠️  Hosting not configured in firebase.json"
    echo "Web previews will be served directly by Cloud Functions"
fi

echo ""

# Update Flutter dependencies
echo "📱 Updating Flutter dependencies..."
flutter pub get

echo ""

# Final verification
echo "✅ Deployment Complete!"
echo ""
echo "🔗 Your SMS invite system is now deployed:"
echo "   - SMS Function: https://us-central1-$PROJECT_ID.cloudfunctions.net/sendSMSInvite"
echo "   - Web Preview: https://$PROJECT_ID.web.app/hangout/[hangoutId]"
echo "   - Deep Link: squadapp://hangout/[hangoutId]"
echo ""
echo "📚 Next steps:"
echo "   1. Test the invite flow in your app"
echo "   2. Send a test SMS invite"
echo "   3. Verify web preview and deep linking"
echo "   4. Check Firebase Console for any errors"
echo ""
echo "📖 For detailed setup instructions, see SMS_INVITE_SETUP.md"

# Test URLs (optional)
read -p "🧪 Generate test URLs? (y/N): " generate_test
if [[ $generate_test =~ ^[Yy]$ ]]; then
    echo ""
    echo "🧪 Test URLs:"
    echo "Web Preview: https://$PROJECT_ID.web.app/hangout/test123?inviter=user456&src=sms"
    echo "Deep Link: squadapp://hangout/test123?inviter=user456"
    echo ""
    echo "Test these URLs to verify your setup!"
fi

echo ""
echo "🎉 Happy inviting!"