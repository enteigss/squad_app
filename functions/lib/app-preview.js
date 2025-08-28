"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.appPreview = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
exports.appPreview = (0, https_1.onRequest)(async (req, res) => {
    try {
        // Handle analytics tracking requests
        if (req.method === 'POST' && req.path.endsWith('/analytics')) {
            try {
                const analyticsData = req.body;
                console.log('Analytics event received:', analyticsData);
                // Store analytics data in Firestore for later analysis
                await admin.firestore().collection('app_invite_analytics').add({
                    ...analyticsData,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
                res.status(200).json({ success: true });
                return;
            }
            catch (error) {
                console.error('Error storing analytics:', error);
                res.status(500).json({ error: 'Failed to store analytics' });
                return;
            }
        }
        // Extract inviter user ID from URL path: /invite/userId123
        const pathParts = req.path.split('/');
        const inviterUserId = pathParts[2]; // /invite/[USER_ID]
        if (!inviterUserId) {
            res.status(404).send(generateErrorPage("Invalid invite link"));
            return;
        }
        // Fetch inviter data from Firestore
        let inviterName = 'A friend';
        let inviterPhoto = null;
        try {
            const inviterDoc = await admin.firestore()
                .collection('users')
                .doc(inviterUserId)
                .get();
            if (inviterDoc.exists) {
                const inviterData = inviterDoc.data();
                inviterName = (inviterData === null || inviterData === void 0 ? void 0 : inviterData.displayName) || (inviterData === null || inviterData === void 0 ? void 0 : inviterData.username) || 'A friend';
                inviterPhoto = (inviterData === null || inviterData === void 0 ? void 0 : inviterData.photoUrl) || null;
            }
        }
        catch (error) {
            console.error('Error fetching inviter data:', error);
            // Continue with default name and no photo
        }
        // Generate the landing page
        const html = generateAppInvitePage(inviterName, inviterPhoto, inviterUserId);
        res.set('Content-Type', 'text/html');
        res.set('Cache-Control', 'public, max-age=300'); // Cache for 5 minutes
        res.send(html);
    }
    catch (error) {
        console.error('Error generating app invite preview:', error);
        res.status(500).send(generateErrorPage("Something went wrong"));
    }
});
function generateAppInvitePage(inviterName, inviterPhoto, inviterUserId) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Join ${inviterName} on LinkUp BU</title>
    
    <!-- Open Graph / Social Media -->
    <meta property="og:title" content="${inviterName} invited you to LinkUp BU!">
    <meta property="og:description" content="Join the app for spontaneous hangouts and activities">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://${process.env.GCLOUD_PROJECT}.web.app/invite/${inviterUserId}">
    <meta property="og:image" content="https://squad-7bc7e.web.app/squad-og-image.png">
    
    <!-- Twitter Cards -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${inviterName} invited you to LinkUp BU!">
    <meta name="twitter:description" content="Join the app for spontaneous hangouts and activities">
    <meta name="twitter:image" content="https://squad-7bc7e.web.app/squad-og-image.png">
    
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
        .app-logo { 
            font-size: 48px; 
            margin-bottom: 16px; 
        }
        .inviter-section {
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 24px;
            gap: 12px;
        }
        .inviter-photo {
            width: 48px;
            height: 48px;
            border-radius: 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 20px;
            font-weight: bold;
        }
        .inviter-photo img {
            width: 100%;
            height: 100%;
            border-radius: 24px;
            object-fit: cover;
        }
        .invite-text { 
            color: #666; 
            font-size: 16px; 
            margin: 0;
        }
        .app-title { 
            font-size: 32px; 
            font-weight: bold; 
            margin: 24px 0 16px 0; 
            color: #333;
            line-height: 1.2;
        }
        .app-subtitle {
            color: #666;
            font-size: 18px;
            margin-bottom: 32px;
            line-height: 1.4;
        }
        .features { 
            margin-bottom: 32px; 
            text-align: left;
        }
        .feature-item { 
            margin-bottom: 16px; 
            display: flex; 
            align-items: flex-start; 
            gap: 12px;
            font-size: 16px;
            color: #555;
        }
        .feature-emoji { 
            font-size: 20px; 
            flex-shrink: 0;
        }
        .feature-text {
            flex: 1;
        }
        .feature-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 4px;
        }
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
            line-height: 1.4;
        }
        @media (max-width: 480px) {
            .container { margin: 10px; padding: 24px 20px; }
            .app-title { font-size: 28px; }
            .app-subtitle { font-size: 16px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="app-logo">🎉</div>
        
        <div class="inviter-section">
            <div class="inviter-photo">
                ${inviterPhoto ? `<img src="${inviterPhoto}" alt="${inviterName}">` : inviterName.charAt(0).toUpperCase()}
            </div>
            <p class="invite-text">${inviterName} invited you to</p>
        </div>
        
        <div class="app-title">LinkUp BU</div>
        <div class="app-subtitle">The app for spontaneous hangouts</div>
        
        <div class="features">
            <div class="feature-item">
                <span class="feature-emoji">🎯</span>
                <div class="feature-text">
                    <div class="feature-title">Find Activities</div>
                    <div>Discover hangouts and events happening around you</div>
                </div>
            </div>
            <div class="feature-item">
                <span class="feature-emoji">👥</span>
                <div class="feature-text">
                    <div class="feature-title">Meet People</div>
                    <div>Connect with like-minded people in your area</div>
                </div>
            </div>
            <div class="feature-item">
                <span class="feature-emoji">💬</span>
                <div class="feature-text">
                    <div class="feature-title">Group Chat</div>
                    <div>Coordinate plans with built-in group messaging</div>
                </div>
            </div>
        </div>

        <!-- Download buttons -->
        <a href="#" class="button primary hidden" id="iosBtn">
            📲 Download for iPhone
        </a>
        
        <a href="#" class="button primary hidden" id="androidBtn">
            🤖 Download for Android
        </a>
        
        <a href="#" class="button secondary" onclick="copyLink()">
            🔗 Copy Link
        </a>
        
        <div class="footer">
            Join LinkUp BU to create and join spontaneous hangouts with friends!<br>
            It's free and takes less than a minute to get started.
        </div>
    </div>

    <script>
        // Platform detection
        const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
        const isAndroid = /Android/.test(navigator.userAgent);
        const isMobile = isIOS || isAndroid;
        
        // Analytics tracking
        function trackEvent(eventName, parameters) {
            // Send to Firebase Analytics if available
            if (typeof gtag !== 'undefined') {
                gtag('event', eventName, parameters);
            }
            
            // Also send to our analytics endpoint for tracking
            fetch('/analytics', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    event: eventName,
                    parameters: parameters,
                    timestamp: new Date().toISOString(),
                    inviterId: '${inviterUserId}',
                    userAgent: navigator.userAgent,
                    platform: isIOS ? 'ios' : isAndroid ? 'android' : 'desktop'
                })
            }).catch(err => console.log('Analytics tracking failed:', err));
        }
        
        // Track page view
        trackEvent('app_invite_page_viewed', {
            inviter_id: '${inviterUserId}',
            inviter_name: '${inviterName}',
            platform: isIOS ? 'ios' : isAndroid ? 'android' : 'desktop',
            source: 'web_preview'
        });
        
        // Show appropriate download buttons
        if (isIOS) {
            document.getElementById('iosBtn').classList.remove('hidden');
            // Replace with your actual TestFlight link
            document.getElementById('iosBtn').href = 'https://testflight.apple.com/join/11Dg3Zh8';
            
            // Track iOS button click
            document.getElementById('iosBtn').addEventListener('click', function() {
                trackEvent('app_download_attempt', {
                    inviter_id: '${inviterUserId}',
                    platform: 'ios',
                    source: 'app_invite'
                });
            });
        } else if (isAndroid) {
            document.getElementById('androidBtn').classList.remove('hidden');
            // Replace with your actual APK download link or Play Store
            document.getElementById('androidBtn').href = 'https://play.google.com/store/apps/details?id=com.jordan.linkupbu';
            
            // Track Android button click
            document.getElementById('androidBtn').addEventListener('click', function() {
                trackEvent('app_download_attempt', {
                    inviter_id: '${inviterUserId}',
                    platform: 'android',
                    source: 'app_invite'
                });
            });
        } else {
            // Desktop - show both options
            document.getElementById('iosBtn').classList.remove('hidden');
            document.getElementById('androidBtn').classList.remove('hidden');
            document.getElementById('iosBtn').href = 'https://testflight.apple.com/join/11Dg3Zh8';
            document.getElementById('androidBtn').href = 'https://play.google.com/store/apps/details?id=com.jordan.linkupbu';
            
            // Track desktop button clicks
            document.getElementById('iosBtn').addEventListener('click', function() {
                trackEvent('app_download_attempt', {
                    inviter_id: '${inviterUserId}',
                    platform: 'ios',
                    source: 'app_invite'
                });
            });
            
            document.getElementById('androidBtn').addEventListener('click', function() {
                trackEvent('app_download_attempt', {
                    inviter_id: '${inviterUserId}',
                    platform: 'android',
                    source: 'app_invite'
                });
            });
        }
        
        function copyLink() {
            // Track copy link action
            trackEvent('app_invite_link_copied', {
                inviter_id: '${inviterUserId}',
                platform: isIOS ? 'ios' : isAndroid ? 'android' : 'desktop'
            });
            
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
        
        // Add loading animation
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
function generateErrorPage(message) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LinkUp BU - ${message}</title>
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
        <p>Download the LinkUp BU app to create and join spontaneous hangouts!</p>
        <a href="/">← Back to LinkUp BU</a>
    </div>
</body>
</html>`;
}
//# sourceMappingURL=app-preview.js.map