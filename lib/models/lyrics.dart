class Lyrics {
  final int id;
  final String lyric;
  final int second;
  
  Lyrics({
    required this.id,
    required this.lyric,
    required this.second,
  });
  
  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      id: json['id'],
      lyric: json['lyric'],
      second: json['second'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lyric': lyric,
      'second': second,
    };
  }
}
