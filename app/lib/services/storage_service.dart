import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  StorageService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  Future<String?> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      
      // Validate file size (limit to 5MB)
      final int fileSizeInBytes = await file.length();
      const int maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      
      if (fileSizeInBytes > maxSizeInBytes) {
        throw Exception('Image size must be less than 5MB');
      }
      
      // Create unique filename with timestamp to avoid conflicts
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'profile_${userId}_$timestamp.jpg';
      
      final Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(fileName);

      // Set metadata for better file management
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'storage/unauthorized':
          throw Exception('You don\'t have permission to upload images');
        case 'storage/canceled':
          throw Exception('Upload was canceled');
        case 'storage/quota-exceeded':
          throw Exception('Storage quota exceeded');
        case 'storage/invalid-format':
          throw Exception('Invalid image format');
        case 'storage/unknown':
        default:
          throw Exception('Upload failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  Future<String?> uploadGroupImage(String groupId, XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      final String fileName = 'group_$groupId.jpg';
      
      final Reference ref = _storage
          .ref()
          .child('group_images')
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadMessageImage(String groupId, XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final Reference ref = _storage
          .ref()
          .child('message_images')
          .child(groupId)
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadFile(String groupId, File file, String fileName) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('message_files')
          .child(groupId)
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<XFile>?> pickMultipleImages() async {
    try {
      return await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'storage/object-not-found':
          // File doesn't exist, which is fine for deletion
          return;
        case 'storage/unauthorized':
          throw Exception('You don\'t have permission to delete this file');
        default:
          throw Exception('Failed to delete file: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  /// Delete old profile image when user uploads a new one
  Future<void> deleteOldProfileImage(String? oldPhotoUrl) async {
    if (oldPhotoUrl == null || oldPhotoUrl.isEmpty) return;
    
    try {
      // Only delete if it's a Firebase Storage URL
      if (oldPhotoUrl.contains('firebasestorage.googleapis.com')) {
        await deleteFile(oldPhotoUrl);
      }
    } catch (e) {
      // Log error but don't throw - failing to delete old image shouldn't break the upload
      print('Warning: Failed to delete old profile image: $e');
    }
  }

  UploadTask? uploadFileWithProgress(String path, File file) {
    try {
      final Reference ref = _storage.ref().child(path);
      return ref.putFile(file);
    } catch (e) {
      rethrow;
    }
  }

  Stream<TaskSnapshot> uploadWithProgress(String groupId, File file, String fileName) {
    final Reference ref = _storage
        .ref()
        .child('message_files')
        .child(groupId)
        .child(fileName);

    final UploadTask uploadTask = ref.putFile(file);
    return uploadTask.snapshotEvents;
  }
}