class BULocations {
  // On-Campus Locations
  static const List<String> onCampusLocations = [
    'BU Beach (large grassy area on campus)',
    'Marsh Plaza',
    'George Sherman Union (GSU)',
    'Mugar Memorial Library',
    'Fenway Campus',
    'Student Village',
    'West Campus',
    'East Campus',
    'Warren Towers',
    'Sleeper Hall',
    'Rich Hall',
    'Bay State Road brownstones',
    'BU Central (dining area)',
    'Fitness & Recreation Center (FitRec)',
    'Agganis Arena',
    'Nickerson Field',
  ];

  // Nearby Off-Campus Popular Spots
  static const List<String> offCampusLocations = [
    'Kenmore Square',
    'Fenway Park area',
    'Newbury Street',
    'Boston Common',
    'Back Bay',
    'Allston',
    'Brighton',
    'Harvard Avenue (Allston)',
    'Commonwealth Avenue',
    'Storrow Drive Esplanade',
    'Charles River',
    'Prudential Center',
    'Copley Square',
  ];

  // Special option for custom location
  static const String otherOption = 'Other (specify your own)';

  // Get all locations in organized order
  static List<String> get allLocations {
    return [
      otherOption,
      ...onCampusLocations,
      ...offCampusLocations,
    ];
  }

  // Get locations organized by category for display
  static Map<String, List<String>> get locationsByCategory {
    return {
      'On-Campus Locations': onCampusLocations,
      'Nearby Off-Campus Spots': offCampusLocations,
    };
  }

  // Helper method to check if a location is "Other"
  static bool isOtherOption(String? location) {
    return location == otherOption;
  }

  // Helper method to get display text for a location
  static String getDisplayText(String? location, String? customLocation) {
    if (location == null || location.isEmpty) {
      return 'Select location';
    }
    if (isOtherOption(location)) {
      return customLocation?.isEmpty != false 
          ? 'Other (tap to specify)'
          : customLocation!;
    }
    return location;
  }
}