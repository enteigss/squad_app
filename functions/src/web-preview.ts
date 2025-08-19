import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";

const app = express();
app.use(cors({origin: true}));

// Helper function to format date/time for display
function formatDateTime(timestamp: any): string {
  if (!timestamp) return "TBD";
  
  const date = timestamp.toDate();
  const now = new Date();
  const isToday = date.toDateString() === now.toDateString();
  const isTomorrow = date.toDateString() === 
    new Date(now.getTime() + 24 * 60 * 60 * 1000).toDateString();
  
  if (isToday) {
    return `Today at ${date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    })}`;
  } else if (isTomorrow) {
    return `Tomorrow at ${date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit", 
      hour12: true,
    })}`;
  } else {
    return `${date.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short", 
      day: "numeric",
    })} at ${date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    })}`;
  }
}

// Helper function to get relative time
function getRelativeTime(timestamp: any): string {
  if (!timestamp) return "";
  
  const date = timestamp.toDate();
  const now = new Date();
  const diffMs = date.getTime() - now.getTime();
  const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
  
  if (diffMs < 0) return "Past event";
  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Tomorrow";
  if (diffDays < 7) return `In ${diffDays} days`;
  return `${date.toLocaleDateString()}`;
}

// Generate the mobile-optimized HTML page
function generateHangoutPreviewHTML(hangout: any, inviterName: string): string {
  const dateTime = formatDateTime(hangout.scheduledTime);
  const relativeTime = getRelativeTime(hangout.scheduledTime);
  const location = hangout.location || "Location TBD";
  const participantCount = hangout.participantIds?.length || 1;
  const description = hangout.description || "";
  
  // Deep link URLs for app stores
  const appStoreUrl = "https://apps.apple.com/app/squad"; // Replace with actual App Store URL
  const playStoreUrl = "https://play.google.com/store/apps/details?id=com.squad.app"; // Replace with actual Play Store URL
  const deepLink = `squadapp://hangout/${hangout.id}?inviter=${hangout.authorId}`;
  
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>Join "${hangout.title}" on Squad</title>
    
    <!-- Open Graph Meta Tags -->
    <meta property="og:title" content="${hangout.title} - Squad Hangout">
    <meta property="og:description" content="${inviterName} invited you to join this hangout. ${participantCount} people going.">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://${process.env.GCLOUD_PROJECT}.web.app/hangout/${hangout.id}">
    
    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${hangout.title} - Squad Hangout">
    <meta name="twitter:description" content="${inviterName} invited you to join this hangout">
    
    <!-- iOS Smart App Banner -->
    <meta name="apple-itunes-app" content="app-id=YOUR_APP_ID, app-argument=${deepLink}">
    
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 400px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
            animation: slideUp 0.6s ease-out;
        }
        
        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .header {
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            padding: 30px 25px;
            text-align: center;
            position: relative;
        }
        
        .header::before {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
            animation: rotate 20s linear infinite;
        }
        
        @keyframes rotate {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
        
        .header-content {
            position: relative;
            z-index: 1;
        }
        
        .logo {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        
        .invitation {
            font-size: 16px;
            opacity: 0.9;
        }
        
        .content {
            padding: 30px 25px;
        }
        
        .hangout-title {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 20px;
            color: #1f2937;
            line-height: 1.3;
        }
        
        .detail-row {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
            padding: 12px;
            background: #f8fafc;
            border-radius: 12px;
            border-left: 4px solid #6366f1;
        }
        
        .detail-icon {
            width: 20px;
            height: 20px;
            margin-right: 12px;
            opacity: 0.7;
        }
        
        .detail-text {
            flex: 1;
            font-size: 14px;
            color: #4b5563;
        }
        
        .detail-text strong {
            color: #1f2937;
            display: block;
            font-size: 15px;
        }
        
        .description {
            background: #f1f5f9;
            padding: 16px;
            border-radius: 12px;
            margin: 20px 0;
            font-size: 14px;
            line-height: 1.5;
            color: #475569;
        }
        
        .participants {
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            color: white;
            padding: 16px;
            border-radius: 12px;
            text-align: center;
            margin: 20px 0;
        }
        
        .participants-count {
            font-size: 28px;
            font-weight: bold;
            display: block;
        }
        
        .participants-label {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .cta-section {
            margin-top: 30px;
            text-align: center;
        }
        
        .join-button {
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            border: none;
            padding: 18px 32px;
            font-size: 18px;
            font-weight: 600;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(99, 102, 241, 0.4);
            width: 100%;
            margin-bottom: 15px;
        }
        
        .join-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(99, 102, 241, 0.6);
        }
        
        .app-links {
            display: flex;
            gap: 10px;
            margin-top: 20px;
        }
        
        .app-link {
            flex: 1;
            padding: 12px 16px;
            background: #374151;
            color: white;
            text-decoration: none;
            border-radius: 12px;
            font-size: 14px;
            text-align: center;
            transition: background 0.3s ease;
        }
        
        .app-link:hover {
            background: #4b5563;
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            font-size: 12px;
            color: #6b7280;
            background: #f9fafb;
        }
        
        .pulse {
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
        @media (max-width: 480px) {
            .container {
                margin: 10px;
                border-radius: 16px;
            }
            
            .content {
                padding: 25px 20px;
            }
            
            .hangout-title {
                font-size: 22px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-content">
                <div class="logo">🎉 Squad</div>
                <div class="invitation">${inviterName} invited you!</div>
            </div>
        </div>
        
        <div class="content">
            <h1 class="hangout-title">${hangout.title}</h1>
            
            <div class="detail-row">
                <svg class="detail-icon" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
                </svg>
                <div class="detail-text">
                    <strong>${dateTime}</strong>
                    ${relativeTime}
                </div>
            </div>
            
            <div class="detail-row">
                <svg class="detail-icon" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd"/>
                </svg>
                <div class="detail-text">
                    <strong>${location}</strong>
                </div>
            </div>
            
            ${description ? `<div class="description">${description}</div>` : ''}
            
            <div class="participants">
                <span class="participants-count">${participantCount}</span>
                <span class="participants-label">people going</span>
            </div>
            
            <div class="cta-section">
                <button class="join-button pulse" onclick="tryOpenApp()">
                    Join Hangout
                </button>
                
                <div class="app-links">
                    <a href="${appStoreUrl}" class="app-link">📱 App Store</a>
                    <a href="${playStoreUrl}" class="app-link">🤖 Play Store</a>
                </div>
            </div>
        </div>
        
        <div class="footer">
            Download Squad to join hangouts with friends
        </div>
    </div>

    <script>
        function tryOpenApp() {
            const deepLink = "${deepLink}";
            const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
            const isAndroid = /Android/.test(navigator.userAgent);
            
            // Try to open the app
            window.location.href = deepLink;
            
            // Fallback to app store after a delay
            setTimeout(() => {
                if (isIOS) {
                    window.location.href = "${appStoreUrl}";
                } else if (isAndroid) {
                    window.location.href = "${playStoreUrl}";
                } else {
                    // Desktop users - show app store links
                    alert("Download the Squad app on your mobile device to join hangouts!");
                }
            }, 2000);
        }
        
        // Auto-redirect if coming from SMS on mobile
        if (window.location.search.includes('src=sms') && 
            (/iPad|iPhone|iPod|Android/.test(navigator.userAgent))) {
            // Small delay to let page load
            setTimeout(tryOpenApp, 1000);
        }
    </script>
</body>
</html>`;
}

// Main handler for hangout preview requests
app.get('/hangout/:hangoutId', async (req: express.Request, res: express.Response) => {
  try {
    const {hangoutId} = req.params;
    const {inviter} = req.query;

    if (!hangoutId) {
      return res.status(400).send("Hangout ID is required");
    }

    // Get hangout details from Firestore
    const hangoutRef = admin.firestore().collection("posts").doc(hangoutId);
    const hangoutDoc = await hangoutRef.get();

    if (!hangoutDoc.exists) {
      return res.status(404).send(`
        <html>
          <body style="font-family: Arial; text-align: center; padding: 50px;">
            <h1>Hangout Not Found</h1>
            <p>This hangout may have been deleted or the link is invalid.</p>
            <a href="https://squad.app">Download Squad App</a>
          </body>
        </html>
      `);
    }

    const hangout = hangoutDoc.data()!;
    
    // Get inviter name if provided
    let inviterName = hangout.authorName || "Someone";
    if (inviter && inviter !== hangout.authorId) {
      try {
        const inviterRef = admin.firestore().collection("users").doc(inviter as string);
        const inviterDoc = await inviterRef.get();
        if (inviterDoc.exists) {
          const inviterData = inviterDoc.data()!;
          inviterName = inviterData.displayName || inviterData.firstName || "Someone";
        }
      } catch (error) {
        // Use default name if we can't fetch inviter details
      }
    }

    // Generate and send HTML
    const html = generateHangoutPreviewHTML(hangout, inviterName);
    res.set('Content-Type', 'text/html');
    return res.send(html);

  } catch (error) {
    console.error("Error generating hangout preview:", error);
    return res.status(500).send(`
      <html>
        <body style="font-family: Arial; text-align: center; padding: 50px;">
          <h1>Error Loading Hangout</h1>
          <p>Something went wrong. Please try again later.</p>
          <a href="https://squad.app">Download Squad App</a>
        </body>
      </html>
    `);
  }
});

export const hangoutPreview = onRequest(app);