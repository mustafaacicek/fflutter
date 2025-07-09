import 'package:intl/intl.dart';

import 'team.dart';

class Match {
  final int id;
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int? opponentTeamId;
  final String? opponentTeamName;
  final String? opponentTeamLogo;
  final String? manualOpponentName;
  final String? manualOpponentLogo;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final DateTime matchDate;
  final DateTime createdAt;
  // Takım bilgilerini taşımak için eklenen alan
  Team? team;

  Match({
    required this.id,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    this.opponentTeamId,
    this.opponentTeamName,
    this.opponentTeamLogo,
    this.manualOpponentName,
    this.manualOpponentLogo,
    required this.status,
    this.homeScore,
    this.awayScore,
    required this.matchDate,
    required this.createdAt,
    this.team,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'],
      teamId: json['teamId'],
      teamName: json['teamName'],
      teamLogo: json['teamLogo'],
      opponentTeamId: json['opponentTeamId'],
      opponentTeamName: json['opponentTeamName'],
      opponentTeamLogo: json['opponentTeamLogo'],
      manualOpponentName: json['manualOpponentName'],
      manualOpponentLogo: json['manualOpponentLogo'],
      status: json['status'],
      homeScore: json['homeScore'],
      awayScore: json['awayScore'],
      matchDate: DateTime.parse(json['matchDate']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Helper method to get opponent name (either from team or manual)
  String getOpponentName() {
    return opponentTeamName ?? manualOpponentName ?? 'Unknown Opponent';
  }

  // Helper method to get opponent logo (either from team or manual)
  String? getOpponentLogo() {
    return opponentTeamLogo ?? manualOpponentLogo;
  }

  // Helper method to format match date
  String getFormattedMatchDate() {
    return DateFormat('dd MMM yyyy HH:mm').format(matchDate);
  }

  // Helper method to get match score as a string
  String getScoreText() {
    if (homeScore == null || awayScore == null) {
      return 'vs';
    }
    return '$homeScore - $awayScore';
  }

  // Helper method to check if the match is upcoming
  bool isUpcoming() {
    return status == 'UPCOMING';
  }

  // Helper method to check if the match is completed
  bool isCompleted() {
    return status == 'COMPLETED';
  }

  // Helper method to check if the match is in progress
  bool isInProgress() {
    return status == 'IN_PROGRESS';
  }
}
