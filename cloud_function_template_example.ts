import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const hangoutPreview = functions.https.onRequest(async (req, res) => {
  try {
    // Extract hangout ID from URL path
    // URL format: /hangout/123 -> hangoutId = '123'
    const pathParts = req.path.split('/');
    const hangoutId = pathParts[pathParts.length - 1];

    if (!hangoutId) {
      res.status(400).send('Missing hangout ID');
      return;
    }

    // Get hangout data from Firestore
    const hangoutDoc = await db.collection('hangouts').doc(hangoutId).get();
    
    if (!hangoutDoc.exists) {
      res.status(404).send('Hangout not found');
      return;
    }

    const hangoutData = hangoutDoc.data();
    
    // Get inviter data if available
    let inviterName = 'Someone';
    if (hangoutData?.inviterId) {
      const inviterDoc = await db.collection('users').doc(hangoutData.inviterId).get();
      if (inviterDoc.exists) {
        const inviterData = inviterDoc.data();
        inviterName = inviterData?.displayName || inviterData?.username || 'Someone';
      }
    }

    // Load the HTML template
    const templatePath = path.join(__dirname, 'hangout_preview_template.html');
    let template: string;
    
    try {
      template = fs.readFileSync(templatePath, 'utf8');
    } catch (error) {
      console.error('Failed to read template file:', error);
      res.status(500).send('Template not found');
      return;
    }

    // Replace template variables with actual data
    const html = template
      .replace(/\{\{hangoutTitle\}\}/g, hangoutData?.title || 'LinkUp BU Hangout')
      .replace(/\{\{hangoutId\}\}/g, hangoutId)
      .replace(/\{\{inviterName\}\}/g, inviterName)
      .replace(/\{\{inviterId\}\}/g, hangoutData?.inviterId || '')
      .replace(/\{\{currentUrl\}\}/g, `https://squad-7bc7e.web.app/hangout/${hangoutId}`)
      .replace(/\{\{testflightUrl\}\}/g, 'https://testflight.apple.com/join/11Dg3Zh8')
      .replace(/\{\{androidBetaUrl\}\}/g, 'https://play.google.com/apps/test/com.jordan.linkupbu/YOUR_INVITATION_CODE');

    // Set appropriate headers
    res.set('Content-Type', 'text/html');
    res.set('Cache-Control', 'public, max-age=300'); // Cache for 5 minutes
    
    // Send the processed HTML
    res.send(html);

  } catch (error) {
    console.error('Error in hangoutPreview function:', error);
    res.status(500).send('Internal server error');
  }
});

// Alternative version using Express-style routing if you prefer
export const hangoutPreviewExpress = functions.https.onRequest(async (req, res) => {
  // Handle CORS for web requests
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    // Extract hangout ID from URL parameters or path
    const hangoutId = req.query.hangoutId as string || req.params.hangoutId;

    if (!hangoutId) {
      res.status(400).json({ error: 'Missing hangout ID' });
      return;
    }

    // Rest of the logic is same as above...
    // (You can copy the logic from the first function)
    
  } catch (error) {
    console.error('Error in hangoutPreviewExpress:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Helper function to validate hangout ID format if needed
function isValidHangoutId(hangoutId: string): boolean {
  // Add your validation logic here
  // For example, check if it's a valid Firestore document ID
  return hangoutId && hangoutId.length > 0 && hangoutId.length < 1500;
}

// Export configuration for Firebase Functions
export const config = {
  // You can add runtime options here if needed
  timeoutSeconds: 60,
  memory: '256MB' as const,
  region: 'us-central1'
};

/* 
DEPLOYMENT INSTRUCTIONS:

1. Copy hangout_preview_template.html to your functions directory:
   functions/src/hangout_preview_template.html

2. Update your functions/src/index.ts:
   export { hangoutPreview } from './hangout-preview';

3. Update your firebase.json hosting rewrites:
   {
     "source": "/hangout/**",
     "function": "hangoutPreview"
   }

4. Deploy:
   firebase deploy --only functions,hosting

5. Update your Android beta URL:
   Replace 'YOUR_INVITATION_CODE' with your actual Google Play closed testing invitation code

6. Test the complete flow:
   - Visit: https://squad-7bc7e.web.app/hangout/test123
   - Should show preview page with correct hangout title and links
   - Test deep link: com.jordan.linkupbu://hangout/test123
   - Test beta links for both iOS and Android
*/