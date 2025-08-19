const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin
admin.initializeApp();

// For cost control
setGlobalOptions({maxInstances: 10});

// Create email transporter
const createTransporter = () => {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: "jordan.anderson.green@gmail.com",
      pass: "fmbx cjxl iolo nhvu",
    },
  });
};

// Function to send party pack invitation email
exports.sendPartyPackInvitation = onDocumentCreated(
    "party_invitations/{invitationId}",
    async (event) => {
      try {
        const invitation = event.data.data();
        const {
          inviteeEmail,
          inviterEmail,
          inviterName,
        } = invitation;

        logger.info("Sending party pack invitation", {
          inviteeEmail,
          inviterEmail,
          inviterName,
        });

        // Create email content
        const inviterDisplay = inviterName || inviterEmail;
        const emailSubject =
          `${inviterDisplay} wants to party pack with you on Squad!`;

        const emailHTML = `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; 
                   color: #333; }
            .container { max-width: 600px; margin: 0 auto; 
                         padding: 20px; }
            .header { background: #6366f1; color: white; padding: 20px; 
                     text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: #f9fafb; padding: 30px; 
                      border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background: #6366f1; 
                     color: white; padding: 12px 24px; 
                     text-decoration: none; border-radius: 6px; 
                     margin: 20px 0; }
            .footer { text-align: center; margin-top: 30px; 
                     color: #666; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🎉 You've been invited to Squad!</h1>
            </div>
            <div class="content">
              <h2>Hey there!</h2>
              <p><strong>${inviterDisplay}</strong> wants to party pack 
                 with you on Squad!</p>

              <p>Squad is a social app where you can connect with friends 
                 and find your perfect party pack partner for activities 
                 and events.</p>

              <h3>What's a Party Pack?</h3>
              <p>A party pack is your designated partner for activities. 
                 When you both choose each other, you become party pack 
                 partners and can enjoy events together!</p>

              <h3>How to accept this invitation:</h3>
              <ol>
                <li>Download the Squad app</li>
                <li>Create your account with this email address 
                    (<strong>${inviteeEmail}</strong>)</li>
                <li>Go to the Squads section</li>
                <li>You'll see ${inviterDisplay}'s party pack request 
                    waiting for you!</li>
                <li>Accept their request to become party pack partners</li>
              </ol>

              <div style="text-align: center; margin: 30px 0;">
                <a href="#" class="button">Download Squad App</a>
              </div>

              <p><em>Note: Make sure to sign up with this exact email 
                 address (${inviteeEmail}) to see your pending 
                 invitation!</em></p>
            </div>
            <div class="footer">
              <p>This invitation was sent from Squad App<br>
              If you didn't expect this email, you can safely ignore it.</p>
            </div>
          </div>
        </body>
        </html>
        `;

        const emailText = `
${inviterDisplay} wants to party pack with you on Squad!

Squad is a social app where you can connect with friends and find your 
perfect party pack partner for activities and events.

What's a Party Pack?
A party pack is your designated partner for activities. When you both 
choose each other, you become party pack partners and can enjoy events 
together!

How to accept this invitation:
1. Download the Squad app
2. Create your account with this email address (${inviteeEmail})
3. Go to the Squads section
4. You'll see ${inviterDisplay}'s party pack request waiting for you!
5. Accept their request to become party pack partners

Note: Make sure to sign up with this exact email address 
(${inviteeEmail}) to see your pending invitation!

---
This invitation was sent from Squad App
If you didn't expect this email, you can safely ignore it.
        `;

        // Create transporter and send email
        const transporter = createTransporter();

        const mailOptions = {
          from: `"Squad App" <${process.env.EMAIL_USER}>`,
          to: inviteeEmail,
          subject: emailSubject,
          text: emailText,
          html: emailHTML,
        };

        await transporter.sendMail(mailOptions);

        // Update invitation status to sent
        await event.data.ref.update({
          emailSent: true,
          emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info("Party pack invitation email sent successfully", {
          inviteeEmail,
          inviterEmail,
        });
      } catch (error) {
        logger.error("Error sending party pack invitation email", error);

        // Update invitation with error status
        await event.data.ref.update({
          emailSent: false,
          emailError: error.message,
          emailErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw error;
      }
    });

// Health check endpoint
exports.healthCheck = onRequest((req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "party-pack-invitations",
  });
});
