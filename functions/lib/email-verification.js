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
exports.validateVerificationCode = exports.sendVerificationEmail = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const nodemailer = __importStar(require("nodemailer"));
const firebase_functions_1 = require("firebase-functions");
const crypto = __importStar(require("crypto"));
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
// Send email verification code
exports.sendVerificationEmail = (0, https_1.onCall)(async (request) => {
    try {
        // Verify user is authenticated
        if (!request.auth) {
            throw new Error("Unauthenticated");
        }
        const { email } = request.data;
        const userId = request.auth.uid;
        // Validate email format and BU domain
        if (!email || typeof email !== "string") {
            throw new Error("Invalid email address");
        }
        const emailLower = email.toLowerCase().trim();
        if (!emailLower.endsWith("@bu.edu")) {
            throw new Error("Email must be a valid @bu.edu address");
        }
        firebase_functions_1.logger.info("Sending verification email", { userId, email: emailLower });
        // Check rate limiting - max 5 attempts per hour
        const now = admin.firestore.Timestamp.now();
        const oneHourAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 60 * 60 * 1000);
        const recentAttempts = await admin.firestore()
            .collection("email_verifications")
            .where("userId", "==", userId)
            .where("createdAt", ">=", oneHourAgo)
            .get();
        if (recentAttempts.size >= 5) {
            throw new Error("Too many verification attempts. Please try again later.");
        }
        // Generate 6-digit verification code
        const code = crypto.randomInt(100000, 999999).toString();
        const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000); // 10 minutes
        // Store verification data
        const verificationData = {
            userId: userId,
            email: emailLower,
            code: code,
            attempts: 0,
            createdAt: now,
            expiresAt: expiresAt,
            verified: false,
        };
        await admin.firestore()
            .collection("email_verifications")
            .doc(userId)
            .set(verificationData);
        // Send email
        const transporter = createTransporter();
        const emailSubject = "Verify your BU email for LinkUp BU";
        const emailHTML = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #6366f1; color: white; padding: 20px;
                 text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9fafb; padding: 30px;
                  border-radius: 0 0 8px 8px; }
        .code { font-size: 32px; font-weight: bold; text-align: center;
               background: #fff; padding: 20px; border-radius: 8px;
               margin: 20px 0; color: #6366f1; letter-spacing: 4px; }
        .footer { text-align: center; margin-top: 30px;
                 color: #666; font-size: 14px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>📧 Verify Your BU Email</h1>
        </div>
        <div class="content">
          <h2>Welcome to LinkUp BU!</h2>
          <p>Please enter this verification code in the LinkUp BU app to complete
             your account setup:</p>

          <div class="code">${code}</div>

          <p><strong>This code will expire in 10 minutes.</strong></p>

          <p>If you didn't request this verification, you can safely
             ignore this email.</p>
        </div>
        <div class="footer">
          <p>LinkUp BU - Boston University<br>
          This is an automated message.</p>
        </div>
      </div>
    </body>
    </html>
    `;
        const emailText = `
LinkUp BU - Email Verification

Please enter this verification code in the LinkUp BU app:

${code}

This code will expire in 10 minutes.

If you didn't request this verification, you can safely ignore this email.

---
LinkUp BU - Boston University
    `;
        const mailOptions = {
            from: `"LinkUp BU" <${process.env.EMAIL_USER || "jordan.anderson.green@gmail.com"}>`,
            to: emailLower,
            subject: emailSubject,
            text: emailText,
            html: emailHTML,
        };
        if (process.env.FUNCTIONS_EMULATOR) {
            firebase_functions_1.logger.info("Emulator mode: skipping actual email send", { userId, email: emailLower, code });
        }
        else {
            await transporter.sendMail(mailOptions);
        }
        firebase_functions_1.logger.info("Verification email sent successfully", { userId, email: emailLower });
        return {
            success: true,
            message: "Verification code sent successfully",
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error sending verification email", error);
        throw new Error(error.message || "Failed to send verification email");
    }
});
// Validate email verification code
exports.validateVerificationCode = (0, https_1.onCall)(async (request) => {
    try {
        // Verify user is authenticated
        if (!request.auth) {
            throw new Error("Unauthenticated");
        }
        const { code } = request.data;
        const userId = request.auth.uid;
        if (!code || typeof code !== "string") {
            throw new Error("Invalid verification code");
        }
        firebase_functions_1.logger.info("Validating verification code", { userId });
        // Get verification document
        const verificationDoc = await admin.firestore()
            .collection("email_verifications")
            .doc(userId)
            .get();
        if (!verificationDoc.exists) {
            throw new Error("No verification code found. Please request a new one.");
        }
        const verification = verificationDoc.data();
        if (!verification) {
            throw new Error("Invalid verification data");
        }
        // Check if code has expired
        const now = admin.firestore.Timestamp.now();
        if (now.toMillis() > verification.expiresAt.toMillis()) {
            throw new Error("Verification code has expired. Please request a new one.");
        }
        // Check attempts limit
        if (verification.attempts >= 3) {
            throw new Error("Too many incorrect attempts. Please request a new code.");
        }
        // Check if code matches
        if (code.trim() !== verification.code) {
            // Increment attempts
            await verificationDoc.ref.update({
                attempts: verification.attempts + 1,
            });
            const remainingAttempts = 3 - (verification.attempts + 1);
            throw new Error(`Incorrect verification code. ${remainingAttempts} attempts remaining.`);
        }
        // Code is valid - update user document
        await admin.firestore().collection("users").doc(userId).update({
            isEmailVerified: true,
            verifiedEmail: verification.email,
            emailVerifiedAt: now,
        });
        // Mark verification as completed
        await verificationDoc.ref.update({
            verified: true,
            verifiedAt: now,
        });
        // Clean up expired verifications for this user
        const expiredQuery = await admin.firestore()
            .collection("email_verifications")
            .where("userId", "==", userId)
            .where("expiresAt", "<", now)
            .get();
        const batch = admin.firestore().batch();
        expiredQuery.docs.forEach((doc) => {
            if (doc.id !== userId) { // Don't delete the current one we just verified
                batch.delete(doc.ref);
            }
        });
        await batch.commit();
        firebase_functions_1.logger.info("Email verification successful", {
            userId,
            email: verification.email,
        });
        return {
            success: true,
            message: "Email verified successfully",
            email: verification.email,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error validating verification code", error);
        throw new Error(error.message || "Failed to validate verification code");
    }
});
//# sourceMappingURL=email-verification.js.map