#!/bin/bash
# Deploy Firestore security rules to both test and prod environments
# This ensures both environments stay in sync

set -e  # Exit on error

echo "🔒 Deploying Firestore security rules to both environments..."
echo ""

# Deploy to test environment
echo "📝 Deploying to TEST environment (linkup-bu-test-environment)..."
firebase deploy --only firestore:rules -P test
echo "✅ Test deployment complete"
echo ""

# Deploy to prod environment
echo "📝 Deploying to PROD environment (squad-7bc7e)..."
firebase deploy --only firestore:rules -P prod
echo "✅ Prod deployment complete"
echo ""

echo "🎉 Security rules successfully synced across both environments!"
