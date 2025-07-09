class Country {
  final int id;
  final String name;
  final String logoUrl;
  final String shortCode;
  final String? description; // Made nullable with '?'
  final int teamCount;

  Country({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.shortCode,
    this.description, // Made optional by removing 'required'
    required this.teamCount,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logoUrl'],
      shortCode: json['shortCode'],
      description: json['description'],
      teamCount: json['teamCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'shortCode': shortCode,
      'description': description,
      'teamCount': teamCount,
    };
  }
}
