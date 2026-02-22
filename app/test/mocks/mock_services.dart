import 'package:mockito/annotations.dart';
import 'package:squad_app/services/auth_service.dart';
import 'package:squad_app/services/post_service.dart';
import 'package:squad_app/services/block_service.dart';
import 'package:squad_app/services/firestore_service.dart';
import 'package:squad_app/services/storage_service.dart';
import 'package:squad_app/services/notification_service.dart';
import 'package:squad_app/services/analytics_service.dart';
import 'package:squad_app/services/feedback_service.dart';
import 'package:squad_app/services/report_service.dart';
import 'package:squad_app/services/chat_service.dart';
import 'package:squad_app/services/account_deletion_service.dart';
import 'package:squad_app/services/email_verification_service.dart';
import 'package:squad_app/services/deep_link_service.dart';

/// Generate mocks for all services using mockito
/// Run: flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  AuthService,
  PostService,
  BlockService,
  FirestoreService,
  StorageService,
  NotificationService,
  AnalyticsService,
  FeedbackService,
  ReportService,
  ChatService,
  AccountDeletionService,
  EmailVerificationService,
  DeepLinkService,
])
void main() {}
