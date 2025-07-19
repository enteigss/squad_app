import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      final String fileName = 'profile_$userId.jpg';
      
      final Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw e;
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
      throw e;
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
      throw e;
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
      throw e;
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
      throw e;
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
      throw e;
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
      throw e;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw e;
    }
  }

  UploadTask? uploadFileWithProgress(String path, File file) {
    try {
      final Reference ref = _storage.ref().child(path);
      return ref.putFile(file);
    } catch (e) {
      throw e;
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