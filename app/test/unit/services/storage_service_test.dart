import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/services/storage_service.dart';

import 'storage_service_test.mocks.dart';

@GenerateMocks([FirebaseStorage, Reference, TaskSnapshot, ImagePicker])
void main() {
  late StorageService storageService;
  late MockFirebaseStorage mockStorage;
  late MockReference mockRef;
  late MockTaskSnapshot mockSnapshot;
  late MockImagePicker mockPicker;
  late Directory tempDir;

  File createTempFile({int sizeInBytes = 100}) {
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}test_image.jpg',
    );
    file.writeAsBytesSync(Uint8List(sizeInBytes));
    return file;
  }

  void setupUploadMocks({
    String downloadUrl =
        'https://firebasestorage.googleapis.com/test/image.jpg',
  }) {
    when(mockStorage.ref()).thenReturn(mockRef);
    when(mockRef.child(any)).thenReturn(mockRef);
    final fakeTask = FakeUploadTask(mockSnapshot);
    when(mockRef.putFile(any)).thenAnswer((_) => fakeTask);
    when(mockRef.putFile(any, any)).thenAnswer((_) => fakeTask);
    when(mockSnapshot.state).thenReturn(TaskState.success);
    when(mockSnapshot.ref).thenReturn(mockRef);
    when(mockRef.getDownloadURL()).thenAnswer((_) async => downloadUrl);
  }

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockRef = MockReference();
    mockSnapshot = MockTaskSnapshot();
    mockPicker = MockImagePicker();
    storageService = StorageService(storage: mockStorage, picker: mockPicker);
    tempDir = Directory.systemTemp.createTempSync('storage_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StorageService', () {
    group('Upload operations', () {
      test('uploadProfileImage rejects files over 5MB', () async {
        final file = createTempFile(sizeInBytes: 5 * 1024 * 1024 + 1);
        final xFile = XFile(file.path);

        await expectLater(
          () => storageService.uploadProfileImage('testUser', xFile),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('less than 5MB'),
            ),
          ),
        );
      });

      test('uploadProfileImage returns download URL on success', () async {
        const expectedUrl =
            'https://firebasestorage.googleapis.com/test/image.jpg';
        setupUploadMocks(downloadUrl: expectedUrl);

        final file = createTempFile();
        final xFile = XFile(file.path);

        final result = await storageService.uploadProfileImage(
          'testUser',
          xFile,
        );

        expect(result, expectedUrl);
      });

      test('uploadProfileImage creates correct storage path', () async {
        setupUploadMocks();

        final file = createTempFile();
        final xFile = XFile(file.path);

        await storageService.uploadProfileImage('testUser', xFile);

        verify(mockRef.child('profile_images')).called(1);
        verify(
          mockRef.child(
            argThat(matches(RegExp(r'^profile_testUser_\d+\.jpg$'))),
          ),
        ).called(1);
      });

      test('uploadGroupImage creates correct storage path', () async {
        setupUploadMocks();

        final file = createTempFile();
        final xFile = XFile(file.path);

        await storageService.uploadGroupImage('testGroup', xFile);

        verify(mockRef.child('group_images')).called(1);
        verify(mockRef.child('group_testGroup.jpg')).called(1);
      });

      test('uploadMessageImage creates correct storage path', () async {
        setupUploadMocks();

        final file = createTempFile();
        final xFile = XFile(file.path);

        await storageService.uploadMessageImage('testGroup', xFile);

        verify(mockRef.child('message_images')).called(1);
        verify(mockRef.child('testGroup')).called(1);
        verify(
          mockRef.child(argThat(matches(RegExp(r'^\d+\.jpg$')))),
        ).called(1);
      });

      test('uploadProfileImage handles Firebase unauthorized error', () async {
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child(any)).thenReturn(mockRef);
        when(mockRef.putFile(any, any)).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'storage/unauthorized',
          ),
        );

        final file = createTempFile();
        final xFile = XFile(file.path);

        await expectLater(
          () => storageService.uploadProfileImage('testUser', xFile),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('permission'),
            ),
          ),
        );
      });
    });

    group('Image picking', () {
      test('pickImageFromGallery uses gallery source with correct config',
          () async {
        final testXFile = XFile('test_gallery.jpg');
        when(
          mockPicker.pickImage(
            source: anyNamed('source'),
            maxWidth: anyNamed('maxWidth'),
            maxHeight: anyNamed('maxHeight'),
            imageQuality: anyNamed('imageQuality'),
          ),
        ).thenAnswer((_) async => testXFile);

        final result = await storageService.pickImageFromGallery();

        expect(result, testXFile);
        verify(
          mockPicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 80,
          ),
        ).called(1);
      });

      test('pickImageFromCamera uses camera source with correct config',
          () async {
        final testXFile = XFile('test_camera.jpg');
        when(
          mockPicker.pickImage(
            source: anyNamed('source'),
            maxWidth: anyNamed('maxWidth'),
            maxHeight: anyNamed('maxHeight'),
            imageQuality: anyNamed('imageQuality'),
          ),
        ).thenAnswer((_) async => testXFile);

        final result = await storageService.pickImageFromCamera();

        expect(result, testXFile);
        verify(
          mockPicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 80,
          ),
        ).called(1);
      });

      test('pickMultipleImages returns list from pickMultiImage', () async {
        final testFiles = [XFile('test1.jpg'), XFile('test2.jpg')];
        when(
          mockPicker.pickMultiImage(
            maxWidth: anyNamed('maxWidth'),
            maxHeight: anyNamed('maxHeight'),
            imageQuality: anyNamed('imageQuality'),
          ),
        ).thenAnswer((_) async => testFiles);

        final result = await storageService.pickMultipleImages();

        expect(result, testFiles);
        expect(result!.length, 2);
        verify(
          mockPicker.pickMultiImage(
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 80,
          ),
        ).called(1);
      });
    });

    group('Delete operations', () {
      test('deleteFile silently handles object-not-found', () async {
        when(mockStorage.refFromURL(any)).thenReturn(mockRef);
        when(mockRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'storage/object-not-found',
          ),
        );

        // Should not throw
        await storageService.deleteFile(
          'https://firebasestorage.googleapis.com/test/old.jpg',
        );
      });

      test('deleteOldProfileImage skips non-Firebase URLs', () async {
        await storageService.deleteOldProfileImage(
          'https://example.com/photo.jpg',
        );

        verifyNever(mockStorage.refFromURL(any));
      });

      test('deleteFile throws on unauthorized', () async {
        when(mockStorage.refFromURL(any)).thenReturn(mockRef);
        when(mockRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'storage/unauthorized',
          ),
        );

        await expectLater(
          () => storageService.deleteFile(
            'https://firebasestorage.googleapis.com/test/file.jpg',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('permission'),
            ),
          ),
        );
      });
    });
  });
}

/// A fake [UploadTask] that resolves to a given [TaskSnapshot] when awaited.
///
/// [UploadTask] implements [Future<TaskSnapshot>], which requires implementing
/// the full Future interface. Mockito-generated mocks don't handle this well,
/// so we use a manual fake that delegates to a real [Future].
class FakeUploadTask extends Fake implements UploadTask {
  final TaskSnapshot _snapshot;
  FakeUploadTask(this._snapshot);

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot value) onValue, {
    Function? onError,
  }) {
    return Future<TaskSnapshot>.value(_snapshot).then(
      onValue,
      onError: onError,
    );
  }

  @override
  Future<TaskSnapshot> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return Future<TaskSnapshot>.value(_snapshot).catchError(
      onError,
      test: test,
    );
  }

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) {
    return Future<TaskSnapshot>.value(_snapshot).whenComplete(action);
  }

  @override
  Stream<TaskSnapshot> asStream() => Stream.value(_snapshot);

  @override
  Future<TaskSnapshot> timeout(
    Duration timeLimit, {
    FutureOr<TaskSnapshot> Function()? onTimeout,
  }) {
    return Future<TaskSnapshot>.value(_snapshot).timeout(
      timeLimit,
      onTimeout: onTimeout,
    );
  }
}
