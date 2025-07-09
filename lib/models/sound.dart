import 'lyrics.dart';

class Sound {
  final int id;
  final String title;
  final String soundUrl;
  final String? soundImageUrl;
  final int teamId;
  final String teamName;
  final String status;
  final int currentMillisecond;
  final DateTime updatedAt;
  bool isDownloaded;
  final List<Lyrics>? lyrics;

  Sound({
    required this.id,
    required this.title,
    required this.soundUrl,
    this.soundImageUrl,
    required this.teamId,
    required this.teamName,
    required this.status,
    required this.currentMillisecond,
    required this.updatedAt,
    this.isDownloaded = false,
    this.lyrics,
  });

  factory Sound.fromJson(Map<String, dynamic> json) {
    // Parse lyrics if available
    List<Lyrics>? lyricsList;
    if (json['lyrics'] != null) {
      lyricsList = (json['lyrics'] as List)
          .map((lyricJson) => Lyrics.fromJson(lyricJson))
          .toList();
    }

    return Sound(
      id: json['id'],
      title: json['title'],
      soundUrl: json['soundUrl'],
      soundImageUrl: json['soundImageUrl'],
      teamId: json['teamId'],
      teamName: json['teamName'],
      status: json['status'],
      currentMillisecond: json['currentMillisecond'] ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isDownloaded: json['isDownloaded'] ?? false,
      lyrics: lyricsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'soundUrl': soundUrl,
      'soundImageUrl': soundImageUrl,
      'teamId': teamId,
      'teamName': teamName,
      'status': status,
      'currentMillisecond': currentMillisecond,
      'updatedAt': updatedAt.toIso8601String(),
      'isDownloaded': isDownloaded,
      'lyrics': lyrics?.map((lyric) => lyric.toJson()).toList(),
    };
  }
}
