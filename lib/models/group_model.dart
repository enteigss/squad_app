class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdAt,
    this.memberIds = const [],
    this.adminIds = const [],
    this.lastMessageId,
    this.lastMessageTime,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      imageUrl: map['imageUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      adminIds: List<String>.from(map['adminIds'] ?? []),
      lastMessageId: map['lastMessageId'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    List<String>? memberIds,
    List<String>? adminIds,
    String? lastMessageId,
    DateTime? lastMessageTime,
    bool? isPrivate,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  bool isAdmin(String userId) {
    return adminIds.contains(userId);
  }

  bool isMember(String userId) {
    return memberIds.contains(userId);
  }
}
