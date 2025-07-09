class Team {
  final int id;
  final String name;
  final String logoUrl;
  final String? stadiumName;
  final String? stadiumLocation;
  final int countryId;
  final String countryName;
  final bool isActive;
  final String? serverUrl;

  Team({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.stadiumName,
    this.stadiumLocation,
    required this.countryId,
    required this.countryName,
    required this.isActive,
    this.serverUrl,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logoUrl'],
      stadiumName: json['stadiumName'],
      stadiumLocation: json['stadiumLocation'],
      countryId: json['countryId'],
      countryName: json['countryName'],
      isActive: json['isActive'] ?? true, // Default to true if null
      serverUrl: json['serverUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'stadiumName': stadiumName,
      'stadiumLocation': stadiumLocation,
      'countryId': countryId,
      'countryName': countryName,
      'isActive': isActive,
      'serverUrl': serverUrl,
    };
  }
}
