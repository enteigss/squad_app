import {onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

interface ReporterInfo {
  uid: string;
  displayName: string;
}

interface ReportedContentInfo {
  contentType: string; // 'hangout' or 'user'
  contentId: string;
  authorId: string;
  contentSnippet: Record<string, any>;
}

interface ReportRequest {
  status: string;
  timestamp: string; // ISO 8601 string from client
  reason: string;
  reporterInfo: ReporterInfo;
  reportedContentInfo: ReportedContentInfo;
}

interface ReportResponse {
  success: boolean;
  reportId?: string;
  message: string;
}

export const submitReport = onCall<ReportRequest, Promise<ReportResponse>>(
  {cors: true},
  async (request) => {
    logger.info("🚩 Report Submission Function - Starting execution");
    
    try {
      logger.info("🔐 Report Submission Function - Checking authentication");
      
      // Verify authentication
      if (!request.auth) {
        logger.error("❌ Report Submission Function - No authentication provided");
        throw new Error("Authentication required");
      }
      
      logger.info(`✅ Report Submission Function - User authenticated: ${request.auth.uid}`);

      const reportData = request.data;
      
      logger.info("📋 Report Submission Function - Request data received:", {
        status: reportData.status,
        reason: reportData.reason,
        contentType: reportData.reportedContentInfo?.contentType,
        contentId: reportData.reportedContentInfo?.contentId,
        reporterUid: reportData.reporterInfo?.uid,
      });

      // Validate input
      logger.info("✅ Report Submission Function - Validating input parameters");
      
      if (!reportData.reason || !reportData.reporterInfo || !reportData.reportedContentInfo) {
        logger.error("❌ Report Submission Function - Missing required fields:", {
          hasReason: !!reportData.reason,
          hasReporterInfo: !!reportData.reporterInfo,
          hasReportedContentInfo: !!reportData.reportedContentInfo,
        });
        throw new Error("Missing required fields");
      }

      if (!reportData.reporterInfo.uid || !reportData.reportedContentInfo.contentId || 
          !reportData.reportedContentInfo.contentType || !reportData.reportedContentInfo.authorId) {
        logger.error("❌ Report Submission Function - Missing nested required fields:", {
          hasReporterUid: !!reportData.reporterInfo.uid,
          hasContentId: !!reportData.reportedContentInfo.contentId,
          hasContentType: !!reportData.reportedContentInfo.contentType,
          hasAuthorId: !!reportData.reportedContentInfo.authorId,
        });
        throw new Error("Missing required nested fields");
      }
      
      logger.info("✅ Report Submission Function - Input validation passed");

      // Verify user is authenticated and matches reporter
      logger.info("🔍 Report Submission Function - Verifying user authorization");
      
      if (request.auth.uid !== reportData.reporterInfo.uid) {
        logger.error("❌ Report Submission Function - User mismatch:", {
          authUid: request.auth.uid,
          reporterUid: reportData.reporterInfo.uid,
        });
        throw new Error("Unauthorized: User mismatch");
      }
      
      logger.info("✅ Report Submission Function - User authorization verified");

      // Prevent self-reporting
      logger.info("🔍 Report Submission Function - Checking for self-reporting");
      
      if (request.auth.uid === reportData.reportedContentInfo.authorId) {
        logger.warn("⚠️ Report Submission Function - User attempting to report their own content:", {
          reporterUid: request.auth.uid,
          authorId: reportData.reportedContentInfo.authorId,
        });
        throw new Error("Cannot report your own content");
      }
      
      logger.info("✅ Report Submission Function - Self-reporting check passed");

      // Check for duplicate reports (same reporter + content)
      logger.info("🔍 Report Submission Function - Checking for duplicate reports");
      
      const existingReportsQuery = await admin.firestore()
        .collection("reports")
        .where("reporterInfo.uid", "==", request.auth.uid)
        .where("reportedContentInfo.contentId", "==", reportData.reportedContentInfo.contentId)
        .limit(1)
        .get();

      if (!existingReportsQuery.empty) {
        logger.warn("⚠️ Report Submission Function - Duplicate report detected:", {
          reporterUid: request.auth.uid,
          contentId: reportData.reportedContentInfo.contentId,
          existingReportId: existingReportsQuery.docs[0].id,
        });
        
        return {
          success: false,
          message: "You have already reported this content",
        };
      }
      
      logger.info("✅ Report Submission Function - No duplicate reports found");

      // Validate content type
      const validContentTypes = ['hangout', 'user'];
      if (!validContentTypes.includes(reportData.reportedContentInfo.contentType)) {
        logger.error("❌ Report Submission Function - Invalid content type:", {
          contentType: reportData.reportedContentInfo.contentType,
          validTypes: validContentTypes,
        });
        throw new Error("Invalid content type");
      }

      // Validate report reason
      const validReasons = ['safety_concern', 'harassment_bullying', 'inappropriate_content', 'spam_scam', 'other'];
      if (!validReasons.includes(reportData.reason)) {
        logger.error("❌ Report Submission Function - Invalid reason:", {
          reason: reportData.reason,
          validReasons: validReasons,
        });
        throw new Error("Invalid report reason");
      }

      logger.info("✅ Report Submission Function - Content type and reason validation passed");

      // Verify the reported content exists
      logger.info("📄 Report Submission Function - Verifying reported content exists");
      
      let contentExists = false;
      const contentType = reportData.reportedContentInfo.contentType;
      const contentId = reportData.reportedContentInfo.contentId;
      
      if (contentType === 'hangout') {
        const hangoutRef = admin.firestore().collection("posts").doc(contentId);
        const hangoutDoc = await hangoutRef.get();
        contentExists = hangoutDoc.exists && !hangoutDoc.data()?.deleted;
        
        logger.info("📋 Report Submission Function - Hangout verification:", {
          contentId,
          exists: hangoutDoc.exists,
          deleted: hangoutDoc.data()?.deleted || false,
          contentExists,
        });
      } else if (contentType === 'user') {
        const userRef = admin.firestore().collection("users").doc(contentId);
        const userDoc = await userRef.get();
        contentExists = userDoc.exists;
        
        logger.info("📋 Report Submission Function - User verification:", {
          contentId,
          exists: userDoc.exists,
          contentExists,
        });
      }

      if (!contentExists) {
        logger.warn("⚠️ Report Submission Function - Reported content not found:", {
          contentType,
          contentId,
        });
        
        return {
          success: false,
          message: "The reported content no longer exists",
        };
      }
      
      logger.info("✅ Report Submission Function - Reported content verified");

      // Create the report document
      logger.info("💾 Report Submission Function - Creating report document");
      
      const reportDocument = {
        status: "pending", // Always start as pending regardless of client input
        timestamp: admin.firestore.FieldValue.serverTimestamp(), // Use server timestamp
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reason: reportData.reason,
        reporterInfo: {
          uid: reportData.reporterInfo.uid,
          displayName: reportData.reporterInfo.displayName || "Unknown User",
        },
        reportedContentInfo: {
          contentType: reportData.reportedContentInfo.contentType,
          contentId: reportData.reportedContentInfo.contentId,
          authorId: reportData.reportedContentInfo.authorId,
          contentSnippet: reportData.reportedContentInfo.contentSnippet || {},
        },
        metadata: {
          clientTimestamp: reportData.timestamp, // Keep client timestamp for reference
          userAgent: request.rawRequest?.headers?.["user-agent"] || "unknown",
          ip: request.rawRequest?.ip || "unknown",
        },
      };

      logger.info("📋 Report Submission Function - Report document prepared:", {
        reason: reportDocument.reason,
        contentType: reportDocument.reportedContentInfo.contentType,
        contentId: reportDocument.reportedContentInfo.contentId,
        reporterUid: reportDocument.reporterInfo.uid,
      });

      const reportRef = await admin.firestore().collection("reports").add(reportDocument);
      const reportId = reportRef.id;
      
      logger.info("✅ Report Submission Function - Report document created successfully:", {
        reportId,
      });

      // Log successful report submission
      logger.info("🎉 Report submission completed successfully", {
        reportId,
        reporterUid: request.auth.uid,
        contentType: reportData.reportedContentInfo.contentType,
        contentId: reportData.reportedContentInfo.contentId,
        reason: reportData.reason,
      });

      return {
        success: true,
        reportId,
        message: "Report submitted successfully. Thank you for helping keep our community safe.",
      };

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : "Unknown error";
      
      logger.error("💥 Report submission function error - Top level catch:", {
        error: errorMessage,
        errorType: error instanceof Error ? error.constructor.name : typeof error,
        stack: error instanceof Error ? error.stack : undefined,
        reporterUid: request.auth?.uid || "unauthenticated",
      });
      
      return {
        success: false,
        message: errorMessage.includes("Authentication required") ? 
          "Authentication required" :
          errorMessage.includes("already reported") ?
          "You have already reported this content" :
          errorMessage.includes("your own content") ?
          "Cannot report your own content" :
          errorMessage.includes("no longer exists") ?
          "The reported content no longer exists" :
          "Failed to submit report. Please try again.",
      };
    }
  }
);