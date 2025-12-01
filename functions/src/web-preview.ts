import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as fs from 'fs';
import * as path from 'path';

/**
 * Helper function to format activity text for web previews
 * Returns format: "{activity} at {location}" or just "{activity}" or just "{location}"
 */
function formatActivityText(hangout: any): string {
  let text = "";

  // Get activity name
  if (hangout.activity === "other" && hangout.customActivity) {
    text = hangout.customActivity;
  } else if (hangout.activity) {
    const activityMap: {[key: string]: string} = {
      "diningHall": "Eating",
      "studying": "Studying",
      "walking": "Walking",
      "fitRec": "Working out",
      "chilling": "Chilling",
      "other": "",
    };
    text = activityMap[hangout.activity] || "";
  }

  // Add location
  if (hangout.location) {
    text = text ? `${text} at ${hangout.location}` : hangout.location;
  }

  // Fallback if no activity or location
  return text || "Hangout";
}

export const hangoutPreview = onRequest(
  {
    cors: true,
    invoker: "public",
  },
  async (req, res) => {
  try {
    // Extract hangout ID from URL path: /hangout/abc123
    const pathParts = req.path.split('/');
    const hangoutId = pathParts[2]; // /hangout/[ID]
    
    if (!hangoutId) {
      res.status(404).send(generateErrorPage("Hangout not found"));
      return;
    }

    // Fetch hangout from Firestore
    const hangoutDoc = await admin.firestore()
      .collection('posts')
      .doc(hangoutId)
      .get();

    if (!hangoutDoc.exists) {
      res.status(404).send(generateErrorPage("This hangout doesn't exist"));
      return;
    }

    const hangout = hangoutDoc.data()!;
    
    // Get inviter data if available
    let inviterName = 'Someone';
    if (hangout.authorId) {
      try {
        const inviterDoc = await admin.firestore()
          .collection('users')
          .doc(hangout.authorId)
          .get();
        if (inviterDoc.exists) {
          const inviterData = inviterDoc.data();
          inviterName = inviterData?.displayName || inviterData?.username || 'Someone';
        }
      } catch (error) {
        console.error('Error fetching inviter data:', error);
        // Continue with default name
      }
    }

    // Generate the landing page using template
    const html = generateHangoutPageFromTemplate(hangout, hangoutId, inviterName);
    
    res.set('Content-Type', 'text/html');
    res.set('Cache-Control', 'public, max-age=300'); // Cache for 5 minutes
    res.send(html);
    
  } catch (error) {
    console.error('Error generating hangout preview:', error);
    res.status(500).send(generateErrorPage("Something went wrong"));
  }
});

function generateHangoutPageFromTemplate(hangout: any, hangoutId: string, inviterName: string): string {
  try {
    // Load the HTML template
    const templatePath = path.join(__dirname, 'hangout_preview_template.html');
    const template = fs.readFileSync(templatePath, 'utf8');

    // Format date/time
    let dateTimeStr = "soon";
    if (hangout.scheduledTime) {
      const date = hangout.scheduledTime.toDate();
      const now = new Date();
      const isToday = date.toDateString() === now.toDateString();
      const isTomorrow = date.toDateString() ===
        new Date(now.getTime() + 24 * 60 * 60 * 1000).toDateString();

      if (isToday) {
        dateTimeStr = `today at ${date.toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        })}`;
      } else if (isTomorrow) {
        dateTimeStr = `tomorrow at ${date.toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        })}`;
      } else {
        dateTimeStr = `${date.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
        })} at ${date.toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
          hour12: true,
        })}`;
      }
    }

    const participantCount = hangout.participantIds?.length || 1;
    const location = hangout.location || "TBD";
    const hangoutTitle = formatActivityText(hangout);

    // Replace template variables with actual data
    const html = template
      .replace(/\{\{hangoutTitle\}\}/g, hangoutTitle)
      .replace(/\{\{hangoutId\}\}/g, hangoutId)
      .replace(/\{\{inviterName\}\}/g, inviterName)
      .replace(/\{\{inviterId\}\}/g, hangout.authorId || '')
      .replace(/\{\{dateTime\}\}/g, dateTimeStr)
      .replace(/\{\{location\}\}/g, location)
      .replace(/\{\{participantCount\}\}/g, participantCount.toString())
      .replace(/\{\{currentUrl\}\}/g, `https://${process.env.GCLOUD_PROJECT}.web.app/hangout/${hangoutId}`)
      .replace(/\{\{testflightUrl\}\}/g, 'https://apps.apple.com/us/app/linkup-bu/id6751476681?platform=iphone')
      .replace(/\{\{androidBetaUrl\}\}/g, 'https://play.google.com/store/apps/details?id=com.jordan.linkupbu');

    return html;
  } catch (error) {
    console.error('Error loading template:', error);
    // Fallback to the original inline HTML generation
    return generateHangoutPage(hangout, hangoutId);
  }
}

function generateHangoutPage(hangout: any, hangoutId: string): string {
  // Format date/time
  let dateTimeStr = "soon";
  if (hangout.scheduledTime) {
    const date = hangout.scheduledTime.toDate();
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    const isTomorrow = date.toDateString() === 
      new Date(now.getTime() + 24 * 60 * 60 * 1000).toDateString();
    
    if (isToday) {
      dateTimeStr = `today at ${date.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
      })}`;
    } else if (isTomorrow) {
      dateTimeStr = `tomorrow at ${date.toLocaleTimeString("en-US", {
        hour: "numeric", 
        minute: "2-digit",
        hour12: true,
      })}`;
    } else {
      dateTimeStr = `${date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      })} at ${date.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit", 
        hour12: true,
      })}`;
    }
  }

  const participantCount = hangout.participantIds?.length || 1;
  const location = hangout.location || "TBD";
  const title = formatActivityText(hangout);

  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Join ${title} - Squad</title>

    <!-- Open Graph / Social Media -->
    <meta property="og:title" content="You're invited to ${title}">
    <meta property="og:description" content="${dateTimeStr} at ${location} • ${participantCount} people going">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://${process.env.GCLOUD_PROJECT}.web.app/hangout/${hangoutId}">
    
    <!-- Twitter Cards -->
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="You're invited to ${title}">
    <meta name="twitter:description" content="${dateTimeStr} at ${location} • ${participantCount} people going">
    
    <style>
        * { box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { 
            max-width: 400px; 
            width: 100%;
            background: white; 
            border-radius: 20px; 
            padding: 32px 24px; 
            box-shadow: 0 10px 40px rgba(0,0,0,0.15);
            text-align: center;
        }
        .emoji { font-size: 48px; margin-bottom: 16px; }
        .invite-text { color: #666; font-size: 16px; margin-bottom: 8px; }
        .title { 
            font-size: 28px; 
            font-weight: bold; 
            margin-bottom: 24px; 
            color: #333;
            line-height: 1.2;
        }
        .details { margin-bottom: 32px; }
        .detail-item { 
            margin-bottom: 12px; 
            display: flex; 
            align-items: center; 
            justify-content: center;
            font-size: 16px;
            color: #555;
        }
        .detail-emoji { margin-right: 8px; font-size: 18px; }
        .button { 
            display: block; 
            width: 100%; 
            padding: 16px; 
            margin-bottom: 12px; 
            border: none; 
            border-radius: 12px; 
            font-size: 16px; 
            font-weight: 600; 
            text-decoration: none; 
            text-align: center; 
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .button:hover { transform: translateY(-1px); }
        .primary { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        .primary:hover { box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4); }
        .secondary { 
            background: #f8f9fa; 
            color: #555; 
            border: 2px solid #e9ecef;
        }
        .secondary:hover { background: #e9ecef; }
        .hidden { display: none; }
        .footer { 
            margin-top: 24px; 
            padding-top: 24px; 
            border-top: 1px solid #eee; 
            color: #999; 
            font-size: 14px;
        }
        @media (max-width: 480px) {
            .container { margin: 10px; padding: 24px 20px; }
            .title { font-size: 24px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">🎉</div>
        <div class="invite-text">You're invited to</div>
        <div class="title">${title}</div>
        
        <div class="details">
            <div class="detail-item">
                <span class="detail-emoji">📅</span>
                <span>${dateTimeStr}</span>
            </div>
            <div class="detail-item">
                <span class="detail-emoji">📍</span>
                <span>${location}</span>
            </div>
            <div class="detail-item">
                <span class="detail-emoji">👥</span>
                <span>${participantCount} people going</span>
            </div>
        </div>

        <!-- Continue in App button (hidden by default) -->
        <a href="com.jordan.linkupbu://hangout/${hangoutId}" class="button primary hidden" id="continueBtn">
            📱 Continue in App
        </a>
        
        <!-- Download buttons -->
        <a href="#" class="button primary hidden" id="iosBtn">
            📲 Download for iPhone
        </a>
        
        <a href="#" class="button primary hidden" id="androidBtn">
            🤖 Download for Android
        </a>
        
        <a href="#" class="button secondary" onclick="copyLink()">
            🔗 Copy Invite Link
        </a>
        
        <div class="footer">
            Join the Squad app to see who's down for anything!
        </div>
    </div>

    <script>
        // Platform detection
        const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
        const isAndroid = /Android/.test(navigator.userAgent);
        const isMobile = isIOS || isAndroid;
        
        // Show appropriate buttons
        if (isIOS) {
            document.getElementById('iosBtn').classList.remove('hidden');
            // Replace with your actual TestFlight link
            document.getElementById('iosBtn').href = 'https://apps.apple.com/us/app/linkup-bu/id6751476681?platform=iphone';
        } else if (isAndroid) {
            document.getElementById('androidBtn').classList.remove('hidden');
            // Replace with your actual APK download link or Firebase App Distribution
            document.getElementById('androidBtn').href = 'https://play.google.com/store/apps/details?id=com.jordan.linkupbu';
        }
        
        // Show "Continue in App" if mobile (user might have app installed)
        if (isMobile) {
            document.getElementById('continueBtn').classList.remove('hidden');
            
            // Try to detect if app is installed (iOS only)
            if (isIOS) {
                // Attempt to open the app, fallback to download if it fails
                document.getElementById('continueBtn').addEventListener('click', function(e) {
                    const timeout = setTimeout(function() {
                        // If we're still here after 500ms, app probably isn't installed
                        document.getElementById('iosBtn').scrollIntoView();
                    }, 500);
                    
                    window.addEventListener('blur', function() {
                        clearTimeout(timeout);
                    });
                });
            }
        }
        
        function copyLink() {
            if (navigator.clipboard) {
                navigator.clipboard.writeText(window.location.href).then(function() {
                    alert('Link copied to clipboard!');
                });
            } else {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = window.location.href;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                alert('Link copied to clipboard!');
            }
        }
        
        // Add some loading animation
        document.addEventListener('DOMContentLoaded', function() {
            const container = document.querySelector('.container');
            container.style.opacity = '0';
            container.style.transform = 'translateY(20px)';
            
            setTimeout(function() {
                container.style.transition = 'all 0.5s ease';
                container.style.opacity = '1';
                container.style.transform = 'translateY(0)';
            }, 100);
        });
    </script>
</body>
</html>`;
}

function generateErrorPage(message: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Squad - ${message}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 40px 20px;
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .error-container {
            max-width: 400px;
            background: white;
            color: #333;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.15);
        }
        h1 { margin-bottom: 16px; color: #333; }
        p { margin-bottom: 24px; color: #666; }
        a { 
            color: #667eea; 
            text-decoration: none; 
            font-weight: 600;
            display: inline-block;
            padding: 12px 24px;
            background: #f8f9fa;
            border-radius: 8px;
            transition: all 0.2s ease;
        }
        a:hover { background: #e9ecef; transform: translateY(-1px); }
        .emoji { font-size: 48px; margin-bottom: 16px; }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="emoji">😕</div>
        <h1>${message}</h1>
        <p>Get the Squad app to create and join hangouts with friends!</p>
        <a href="/">← Back to Squad</a>
    </div>
</body>
</html>`;
}