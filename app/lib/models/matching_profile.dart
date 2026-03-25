/// Activity ratings for matching (1-5 scale)
/// Keep in sync with: scripts/matching/src/types.ts
class ActivityRatings {
  final int deepConversations; // "having deep/intellectual conversations"
  final int outdoors; // "doing stuff outdoors"
  final int chilling; // "just chilling"
  final int competitiveGames; // "competitive games (video games, board games, etc.)"
  final int meals; // "grabbing a meal"
  final int nightsOut; // "nights out"

  ActivityRatings({
    this.deepConversations = 3,
    this.outdoors = 3,
    this.chilling = 3,
    this.competitiveGames = 3,
    this.meals = 3,
    this.nightsOut = 3,
  });

  factory ActivityRatings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ActivityRatings();
    return ActivityRatings(
      deepConversations: map['deepConversations'] ?? 3,
      outdoors: map['outdoors'] ?? 3,
      chilling: map['chilling'] ?? 3,
      competitiveGames: map['competitiveGames'] ?? 3,
      meals: map['meals'] ?? 3,
      nightsOut: map['nightsOut'] ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deepConversations': deepConversations,
      'outdoors': outdoors,
      'chilling': chilling,
      'competitiveGames': competitiveGames,
      'meals': meals,
      'nightsOut': nightsOut,
    };
  }

  ActivityRatings copyWith({
    int? deepConversations,
    int? outdoors,
    int? chilling,
    int? competitiveGames,
    int? meals,
    int? nightsOut,
  }) {
    return ActivityRatings(
      deepConversations: deepConversations ?? this.deepConversations,
      outdoors: outdoors ?? this.outdoors,
      chilling: chilling ?? this.chilling,
      competitiveGames: competitiveGames ?? this.competitiveGames,
      meals: meals ?? this.meals,
      nightsOut: nightsOut ?? this.nightsOut,
    );
  }
}

/// Matching profile stored in user document
/// Keep in sync with: scripts/matching/src/types.ts
class MatchingProfile {
  final bool isActive;
  final String? genderPreference;
  final String? funActivities;
  final String? talkAboutForever;
  final String? freeTime;
  final ActivityRatings activityRatings;
  final String? activityPreferencesElaboration;
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
    ActivityRatings? activityRatings,
    this.activityPreferencesElaboration,
    this.friendType,
    this.friendTypeMatchWell,
    this.friendTypeNoMatch,
    this.updatedAt,
  }) : activityRatings = activityRatings ?? ActivityRatings();

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
      activityRatings: ActivityRatings.fromMap(map['activityRatings']),
      activityPreferencesElaboration: map['activityPreferencesElaboration'],
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
      'activityRatings': activityRatings.toMap(),
      'activityPreferencesElaboration': activityPreferencesElaboration,
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
    ActivityRatings? activityRatings,
    String? activityPreferencesElaboration,
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
      activityRatings: activityRatings ?? this.activityRatings,
      activityPreferencesElaboration: activityPreferencesElaboration ?? this.activityPreferencesElaboration,
      friendType: friendType ?? this.friendType,
      friendTypeMatchWell: friendTypeMatchWell ?? this.friendTypeMatchWell,
      friendTypeNoMatch: friendTypeNoMatch ?? this.friendTypeNoMatch,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
