import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/block_service.dart';

class ChatProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final BlockService _blockService = BlockService();
  
  List<GroupModel> _groups = [];
  List<MessageModel> _messages = [];
  List<MessageModel> _filteredMessages = [];
  GroupModel? _currentGroup;
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String? _error;
  UserModel? _currentUser;

  List<GroupModel> get groups => _groups;
  List<MessageModel> get messages => _filteredMessages;
  GroupModel? get currentGroup => _currentGroup;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  String? get error => _error;

  void loadUserGroups(String userId) {
    _firestoreService.getUserGroups(userId).listen(
      (groups) {
        _groups = groups;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load groups: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  void loadGroupMessages(String groupId) {
    _firestoreService.getGroupMessages(groupId).listen(
      (messages) {
        _messages = messages;
        _filterMessages();
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load messages: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  void _filterMessages() {
    if (_currentUser == null) {
      _filteredMessages = _messages;
      return;
    }

    // For now, completely filter out blocked user messages
    // In the future, could add a flag to show placeholder messages
    _filteredMessages = _messages.where((message) {
      return !_blockService.shouldFilterContent(
        message.senderId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );
    }).toList();
  }

  /// Check if a message is from a blocked user
  bool isMessageFromBlockedUser(String senderId) {
    if (_currentUser == null) return false;
    return _blockService.shouldFilterContent(
      senderId,
      _currentUser!.blockedUserIds,
      _currentUser!.blockedByUserIds,
    );
  }

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    _filterMessages();
    notifyListeners();
  }

  Future<void> setCurrentGroup(String groupId) async {
    try {
      _setLoading(true);
      _clearError();
      
      _currentGroup = await _firestoreService.getGroup(groupId);
      if (_currentGroup != null) {
        loadGroupMessages(groupId);
      }
    } catch (e) {
      _error = 'Failed to load group: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createGroup({
    required String name,
    required String createdBy,
    String? description,
    String? imageUrl,
    List<String> memberIds = const [],
    bool isPrivate = false,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final GroupModel newGroup = await _firestoreService.createGroup(
        name: name,
        createdBy: createdBy,
        description: description,
        imageUrl: imageUrl,
        memberIds: memberIds,
        isPrivate: isPrivate,
      );
      
      _groups.insert(0, newGroup);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create group: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderAvatar,
    String? replyToMessageId,
  }) async {
    if (content.trim().isEmpty) return;

    try {
      _setSendingMessage(true);
      _clearError();
      
      await _firestoreService.sendMessage(
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        content: content.trim(),
        type: MessageType.text,
        senderAvatar: senderAvatar,
        replyToMessageId: replyToMessageId,
      );
    } catch (e) {
      _error = 'Failed to send message: ${e.toString()}';
      rethrow;
    } finally {
      _setSendingMessage(false);
    }
  }

  Future<void> sendImageMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required XFile imageFile,
    String? caption,
    String? senderAvatar,
    String? replyToMessageId,
  }) async {
    try {
      _setSendingMessage(true);
      _clearError();
      
      final String? imageUrl = await _storageService.uploadMessageImage(
        groupId,
        imageFile,
      );
      
      if (imageUrl != null) {
        await _firestoreService.sendMessage(
          groupId: groupId,
          senderId: senderId,
          senderName: senderName,
          content: caption ?? '',
          type: MessageType.image,
          senderAvatar: senderAvatar,
          imageUrl: imageUrl,
          replyToMessageId: replyToMessageId,
        );
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      _error = 'Failed to send image: ${e.toString()}';
      rethrow;
    } finally {
      _setSendingMessage(false);
    }
  }

  Future<void> addUserToGroup(String groupId, String userId) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _firestoreService.addUserToGroup(groupId, userId);
      
      final int groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        _groups[groupIndex] = _groups[groupIndex].copyWith(
          memberIds: [..._groups[groupIndex].memberIds, userId],
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to add user to group: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeUserFromGroup(String groupId, String userId) async {
    try {
      _setLoading(true);
      _clearError();
      
      await _firestoreService.removeUserFromGroup(groupId, userId);
      
      final int groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final List<String> updatedMembers = _groups[groupIndex].memberIds
            .where((id) => id != userId)
            .toList();
        final List<String> updatedAdmins = _groups[groupIndex].adminIds
            .where((id) => id != userId)
            .toList();
        
        _groups[groupIndex] = _groups[groupIndex].copyWith(
          memberIds: updatedMembers,
          adminIds: updatedAdmins,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to remove user from group: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markMessageAsRead(String groupId, String messageId, String userId) async {
    try {
      await _firestoreService.markMessageAsRead(groupId, messageId, userId);
    } catch (e) {
      print('Failed to mark message as read: $e');
    }
  }

  Future<void> editMessage(String groupId, String messageId, String newContent) async {
    try {
      await _firestoreService.editMessage(groupId, messageId, newContent);
    } catch (e) {
      _error = 'Failed to edit message: ${e.toString()}';
      rethrow;
    }
  }

  Future<void> deleteMessage(String groupId, String messageId) async {
    try {
      await _firestoreService.deleteMessage(groupId, messageId);
    } catch (e) {
      _error = 'Failed to delete message: ${e.toString()}';
      rethrow;
    }
  }

  void clearCurrentGroup() {
    _currentGroup = null;
    _messages.clear();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSendingMessage(bool sending) {
    _isSendingMessage = sending;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}