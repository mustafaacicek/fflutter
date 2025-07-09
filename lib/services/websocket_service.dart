import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/team.dart';
import '../providers/api_provider.dart';
import '../models/match.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();

  // Track current match ID
  String? _currentMatchId;
  bool _isReconnecting = false;

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  // Getter for the message stream
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Connection status
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> connectionStatus = ValueNotifier<String>(
    'Bağlantı bekleniyor...',
  );

  // API Provider for fetching team data
  final ApiProvider _apiProvider = ApiProvider();
  
  // Last connection URL for debugging
  String? lastConnectionUrl;
  
  /// WebSocket bağlantısını başlatır
  /// [matchId] - Bağlanılacak maçın ID'si
  /// [match] - Opsiyonel olarak maç nesnesi (takım bilgisi içerebilir)
  /// Returns true if connection was successful, false otherwise
  Future<bool> connect(dynamic matchId, {Match? match}) async {
    try {
      // Close existing connection if any
      if (_channel != null) {
        print('Closing existing connection before connecting to match $matchId');
        disconnect();
      }

      // Store current match ID and convert to string if needed
      _currentMatchId = matchId.toString();
      
      // Check if match already has team information attached
      Team? matchTeam;
      
      // If match object is provided and has team information, use it directly
      if (match != null && match.team != null) {
        matchTeam = match.team;
        print('Using team from match object: ${matchTeam?.name}, ID: ${matchTeam?.id}, serverUrl: ${matchTeam?.serverUrl}');
      } else {
        // Otherwise, fetch team information
        print('Fetching teams for match $matchId');
        final teamsResponse = await _apiProvider.getTeams();
        
        if (teamsResponse.success && teamsResponse.data != null) {
          print('Successfully fetched ${teamsResponse.data!.length} teams');
          // Debug: Print all teams and their serverUrls
          for (var team in teamsResponse.data!) {
            print('Team: ${team.name}, ID: ${team.id}, serverUrl: ${team.serverUrl}');
          }
          
          // Try to find the team for this match
          try {
            print('Fetching match details for match $matchId');
            final matchResponse = await _apiProvider.getMatch(matchId);
            
            if (matchResponse.success && matchResponse.data != null) {
              final Match matchData = matchResponse.data!;
              print('Match details - ID: ${matchData.id}, TeamID: ${matchData.teamId}');
              
              // Find the team for this match
              for (var team in teamsResponse.data!) {
                if (team.id == matchData.teamId) {
                  matchTeam = team;
                  print('Found team for match: ${team.name}, ID: ${team.id}, serverUrl: ${team.serverUrl}');
                  break;
                }
              }
            } else {
              print('ERROR: Failed to fetch match details for match $matchId');
              if (matchResponse.error != null) {
                print('Error message: ${matchResponse.error}');
              }
            }
          } catch (e) {
            print('Exception while fetching match details: $e');
          }
          
          // If we still don't have a team, try to find it by matchId
          // This is a fallback in case the match API fails but we know the team ID
          if (matchTeam == null) {
            // Try to find team by assuming matchId might be teamId in some cases
            String matchIdStr = matchId.toString();
            int? matchIdInt;
            try {
              matchIdInt = int.tryParse(matchIdStr);
            } catch (e) {
              print('Could not parse matchId to int: $e');
            }
            
            for (var team in teamsResponse.data!) {
              if ((matchIdInt != null && team.id == matchIdInt) || team.id.toString() == matchIdStr) {
                matchTeam = team;
                print('Fallback: Using team with ID matching matchId: ${team.name}, serverUrl: ${team.serverUrl}');
                break;
              }
            }
          }
        }
      }
      
      // Check if team has a serverUrl
      if (matchTeam == null) {
        print('ERROR: Team not found for match $matchId');
        connectionStatus.value = 'Takım bulunamadı';
        isConnected.value = false;
        return false;
      }
      
      print('Checking serverUrl for team ${matchTeam.name}: "${matchTeam.serverUrl}"');
      
      if (matchTeam.serverUrl == null || matchTeam.serverUrl!.trim().isEmpty) {
        // Team has no serverUrl, don't connect at all
        print('Team ${matchTeam.name} has no serverUrl, WebSocket connection not allowed');
        connectionStatus.value = 'Bu takım için WebSocket bağlantısı desteklenmiyor';
        isConnected.value = false;
        return false;
      }
      
      // Create WebSocket URL from team's serverUrl
      print('Using team serverUrl: "${matchTeam.serverUrl}"');
      String wsUrl = matchTeam.serverUrl!.trim();
      
      // Debug URL parts
      Uri? uri;
      try {
        uri = Uri.parse(wsUrl);
        print('Parsed URL - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
      } catch (e) {
        print('Error parsing URL: $e');
        // Try to fix common URL issues
        if (!wsUrl.startsWith('http://') && !wsUrl.startsWith('https://')) {
          wsUrl = 'http://' + wsUrl;
          print('Added http:// protocol to fix parsing: $wsUrl');
          try {
            uri = Uri.parse(wsUrl);
            print('Re-parsed URL - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
          } catch (e) {
            print('Still error parsing URL: $e');
            connectionStatus.value = 'Geçersiz URL formatı: $wsUrl';
            isConnected.value = false;
            return false;
          }
        } else {
          connectionStatus.value = 'Geçersiz URL formatı: $wsUrl';
          isConnected.value = false;
          return false;
        }
      }
      
      // Convert HTTP to WebSocket protocol
      if (wsUrl.startsWith('https://')) {
        wsUrl = wsUrl.replaceFirst('https://', 'wss://');
        print('Converted HTTPS to WSS: $wsUrl');
      } else if (wsUrl.startsWith('http://')) {
        wsUrl = wsUrl.replaceFirst('http://', 'ws://');
        print('Converted HTTP to WS: $wsUrl');
      } else {
        print('URL does not start with http:// or https://, using as is');
        // Try to add protocol if missing
        if (!wsUrl.contains('://')) {
          wsUrl = 'ws://' + wsUrl;
          print('Added ws:// protocol to URL: $wsUrl');
        }
      }
      
      // Add endpoint
      if (wsUrl.endsWith('/')) {
        wsUrl = wsUrl + 'match-socket/$matchId';
        print('Added endpoint to URL with trailing slash: $wsUrl');
      } else {
        wsUrl = wsUrl + '/match-socket/$matchId';
        print('Added endpoint to URL without trailing slash: $wsUrl');
      }
      
      // Save last connection URL for debugging
      lastConnectionUrl = wsUrl;
      
      print('Connecting to WebSocket: $wsUrl');
      connectionStatus.value = 'Bağlanıyor... ($wsUrl)';
      _isReconnecting = false;

      try {
        _channel = IOWebSocketChannel.connect(
          wsUrl,
          pingInterval: const Duration(seconds: 10),
          connectTimeout: const Duration(seconds: 10),
        );
        
        print('WebSocket connection established successfully');
      } catch (e) {
        print('Error creating WebSocket connection: $e');
        connectionStatus.value = 'Bağlantı hatası: $e\nURL: $wsUrl';
        isConnected.value = false;
        return false;
      }

      // Listen for messages
      _channel!.stream.listen(
        (dynamic message) {
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              print('Received WebSocket message for match $matchId: $data');
              _messageController.add(data);
              isConnected.value = true;
              connectionStatus.value = 'Bağlı ($lastConnectionUrl)';
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
            connectionStatus.value = 'Mesaj işleme hatası: $e';
          }
        },
        onError: (error) {
          print('WebSocket error for match $matchId: $error');
          isConnected.value = false;
          connectionStatus.value = 'Bağlantı hatası: $error\nURL: $lastConnectionUrl';

          // Try to reconnect immediately and then with backoff if needed
          if (!_isReconnecting && _currentMatchId == matchId) {
            _isReconnecting = true;
            print('Attempting immediate reconnect to match $matchId');

            // Try immediate reconnect
            Future.delayed(Duration(milliseconds: 500), () {
              if (_currentMatchId == matchId) {
                print('Immediate reconnect attempt for match $matchId');
                _isReconnecting = false;
                connect(matchId);
              }
            });
          }
        },
        onDone: () {
          print('WebSocket connection closed for match $matchId');
          isConnected.value = false;
          connectionStatus.value = 'Bağlantı kapandı\nURL: $lastConnectionUrl';

          // Try to reconnect if not explicitly disconnected and not in reconnecting state
          if (_currentMatchId != null &&
              _currentMatchId == matchId &&
              !_isReconnecting) {
            print('Connection closed unexpectedly, attempting to reconnect');
            _isReconnecting = true;
            Future.delayed(Duration(seconds: 2), () {
              if (_currentMatchId == matchId) {
                print(
                  'Reconnecting after connection closed for match $matchId',
                );
                _isReconnecting = false;
                connect(matchId);
              } else {
                _isReconnecting = false;
              }
            });
          }
        },
      );
      
      return true; // Connection established successfully
    } catch (e) {
      print('Error connecting to WebSocket for match $matchId: $e');
      isConnected.value = false;
      connectionStatus.value = 'Bağlantı hatası: $e' + (lastConnectionUrl != null ? '\nURL: $lastConnectionUrl' : '');

      // Try to reconnect after a short delay
      Future.delayed(Duration(seconds: 2), () {
        if (_currentMatchId == matchId) {
          print('Retrying connection after error for match $matchId');
          connect(matchId);
        }
      });
      
      return false; // Connection failed
    }
  }

  // Disconnect from WebSocket
  // Normal disconnect - may allow reconnection in some cases
  void disconnect() {
    if (_channel != null) {
      print('Disconnecting from WebSocket for match $_currentMatchId');
      _channel!.sink.close();
      _channel = null;
      isConnected.value = false;
      connectionStatus.value = 'Bağlantı kapalı' + (lastConnectionUrl != null ? '\nURL: $lastConnectionUrl' : '');
      // Not clearing _currentMatchId to allow potential reconnects
    }
  }

  // Force disconnect - completely cleans up and prevents reconnection
  void forceDisconnect() {
    if (_channel != null) {
      print('Force disconnecting from WebSocket for match $_currentMatchId');
      _channel!.sink.close();
      _channel = null;
    }
    _currentMatchId = null;
    _isReconnecting = false;
    isConnected.value = false;
    connectionStatus.value = 'Bağlantı kapalı' + (lastConnectionUrl != null ? '\nURL: $lastConnectionUrl' : '');
  }

  // Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
