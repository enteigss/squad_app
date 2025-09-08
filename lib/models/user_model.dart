class UserModel {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final int? age;
  final String? location;
  final List<String> interests;
  final String? gender;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isOnline;
  final String? groupId;
  final bool hasCreatedProfile;
  final String? fcmToken;
  final List<String> subscribedTopics;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.age,
    this.location,
    this.interests = const [],
    this.gender,
    required this.createdAt,
    this.lastSeen,
    this.isOnline = false,
    this.groupId,
    this.hasCreatedProfile = false,
    this.fcmToken,
    this.subscribedTopics = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      age: map['age'],
      location: map['location'],
      interests: List<String>.from(map['interests'] ?? []),
      gender: map['gender'],
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      lastSeen: _parseDateTime(map['lastSeen']),
      isOnline: map['isOnline'] ?? false,
      groupId: map['groupId'],
      hasCreatedProfile: map['hasCreatedProfile'] ?? false,
      fcmToken: map['fcmToken'],
      subscribedTopics: List<String>.from(map['subscribedTopics'] ?? []),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate();
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'age': age,
      'location': location,
      'interests': interests,
      'gender': gender,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'groupId': groupId,
      'hasCreatedProfile': hasCreatedProfile,
      'fcmToken': fcmToken,
      'subscribedTopics': subscribedTopics,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
    String? gender,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    String? groupId,
    bool? hasCreatedProfile,
    String? fcmToken,
    List<String>? subscribedTopics,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      location: location ?? this.location,
      interests: interests ?? this.interests,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      groupId: groupId ?? this.groupId,
      hasCreatedProfile: hasCreatedProfile ?? this.hasCreatedProfile,
      fcmToken: fcmToken ?? this.fcmToken,
      subscribedTopics: subscribedTopics ?? this.subscribedTopics,
    );
  }
}
