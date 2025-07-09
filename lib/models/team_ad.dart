class TeamAd {
  final int id;
  final String? title;
  final String? description;
  final String imageUrl;
  final String? redirectUrl;
  final int? displayOrder;
  final bool isActive;
  final int teamId;
  final String? startDate;
  final String? endDate;
  final String adPosition;
  final String adType;
  final String? createdAt;
  final String? updatedAt;

  TeamAd({
    required this.id,
    this.title,
    this.description,
    required this.imageUrl,
    this.redirectUrl,
    this.displayOrder,
    required this.isActive,
    required this.teamId,
    this.startDate,
    this.endDate,
    required this.adPosition,
    required this.adType,
    this.createdAt,
    this.updatedAt,
  });

  factory TeamAd.fromJson(Map<String, dynamic> json) {
    print('Parsing TeamAd from JSON: ${json.toString()}');
    
    return TeamAd(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'] ?? '',
      redirectUrl: json['redirectUrl'],
      displayOrder: json['displayOrder'],
      isActive: json['isActive'] ?? false,
      // Backend'den doğrudan teamId geliyor, team nesnesi değil
      teamId: json['teamId'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      adPosition: json['adPosition'] ?? 'UNKNOWN',
      adType: json['adType'] ?? 'UNKNOWN',
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'redirectUrl': redirectUrl,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'teamId': teamId,
      'startDate': startDate,
      'endDate': endDate,
      'adPosition': adPosition,
      'adType': adType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
