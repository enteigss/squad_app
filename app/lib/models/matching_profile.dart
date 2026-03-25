/// Matching profile stored in user document
/// Keep in sync with: scripts/matching/src/types.ts
class MatchingProfile {
  final bool isActive;
  final String? genderPreference;
  final String? funActivities;
  final String? talkAboutForever;
  final String? freeTime;
  final List<String> excludedActivities;
  final List<String> rankedActivities;
  final String? friendType;
  final String? friendTypeMatchWell;
  final String? friendTypeNoMatch;
  final DateTime? updatedAt;

  MatchingProfile({
    this.isActive = false,
    this.genderPreference,
    this.funActivities,
    this.talkAboutForever,
    this.freeTime,
    this.excludedActivities = const [],
    this.rankedActivities = const [],
    this.friendType,
    this.friendTypeMatchWell,
    this.friendTypeNoMatch,
    this.updatedAt,
  });

  factory MatchingProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return MatchingProfile();
    }
    return MatchingProfile(
      isActive: map['isActive'] ?? false,
      genderPreference: map['genderPreference'],
      funActivities: map['funActivities'],
      talkAboutForever: map['talkAboutForever'],
      freeTime: map['freeTime'],
      excludedActivities: List<String>.from(map['excludedActivities'] ?? []),
      rankedActivities: List<String>.from(map['rankedActivities'] ?? []),
      friendType: map['friendType'],
      friendTypeMatchWell: map['friendTypeMatchWell'],
      friendTypeNoMatch: map['friendTypeNoMatch'],
      updatedAt: _parseDateTime(map['updatedAt']),
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
      'isActive': isActive,
      'genderPreference': genderPreference,
      'funActivities': funActivities,
      'talkAboutForever': talkAboutForever,
      'freeTime': freeTime,
      'excludedActivities': excludedActivities,
      'rankedActivities': rankedActivities,
      'friendType': friendType,
      'friendTypeMatchWell': friendTypeMatchWell,
      'friendTypeNoMatch': friendTypeNoMatch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  MatchingProfile copyWith({
    bool? isActive,
    String? genderPreference,
    String? funActivities,
    String? talkAboutForever,
    String? freeTime,
    List<String>? excludedActivities,
    List<String>? rankedActivities,
    String? friendType,
    String? friendTypeMatchWell,
    String? friendTypeNoMatch,
    DateTime? updatedAt,
  }) {
    return MatchingProfile(
      isActive: isActive ?? this.isActive,
      genderPreference: genderPreference ?? this.genderPreference,
      funActivities: funActivities ?? this.funActivities,
      talkAboutForever: talkAboutForever ?? this.talkAboutForever,
      freeTime: freeTime ?? this.freeTime,
      excludedActivities: excludedActivities ?? this.excludedActivities,
      rankedActivities: rankedActivities ?? this.rankedActivities,
      friendType: friendType ?? this.friendType,
      friendTypeMatchWell: friendTypeMatchWell ?? this.friendTypeMatchWell,
      friendTypeNoMatch: friendTypeNoMatch ?? this.friendTypeNoMatch,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
