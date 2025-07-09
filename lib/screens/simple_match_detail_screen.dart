import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fanlaflutter/models/match.dart';
import 'package:fanlaflutter/models/sound.dart';
import 'package:fanlaflutter/models/lyrics.dart';
import 'package:fanlaflutter/services/audio_service.dart';
import 'package:fanlaflutter/services/sound_manager.dart';
import 'package:fanlaflutter/services/websocket_service.dart';
import 'package:fanlaflutter/providers/api_provider.dart';

class SimpleMatchDetailScreen extends StatefulWidget {
  final Match match;

  const SimpleMatchDetailScreen({Key? key, required this.match})
    : super(key: key);

  @override
  State<SimpleMatchDetailScreen> createState() =>
      _SimpleMatchDetailScreenState();
}

class _SimpleMatchDetailScreenState extends State<SimpleMatchDetailScreen> {
  // Services
  final AudioService _audioService = AudioService();
  late final SoundManager _soundManager;
  late final ApiProvider _apiProvider;
  final WebSocketService _webSocketService = WebSocketService();

  // WebSocket connection
  StreamSubscription? _webSocketSubscription;

  // Sound data
  Sound? _currentSound;
  bool _isLoading = true;
  List<Sound> _teamSounds = [];
  List<Lyrics>? _currentLyrics = [];

  // Sound control flags
  bool _blockPlayback = false;
  String _lastSoundStatus = '';

  // Local timing mechanism
  int _localCurrentMillisecond = 0;
  int _lastReceivedMillisecond = 0;
  DateTime? _localTimerStartTime;
  Timer? _localPositionTimer;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _apiProvider = ApiProvider();
    _soundManager = SoundManager(apiProvider: _apiProvider);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize audio service
    await _audioService.init();

    // Load team sounds first
    await _loadTeamSounds();

    // Connect to WebSocket
    _connectToWebSocket();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadTeamSounds() async {
    try {
      print('Loading team sounds for team ID: ${widget.match.teamId}');
      final sounds = await _apiProvider.getStoredSounds(widget.match.teamId);
      setState(() {
        _teamSounds = sounds;
      });
      print('Loaded ${sounds.length} team sounds');
    } catch (e) {
      print('Error loading team sounds: $e');
    }
  }

  void _connectToWebSocket() {
    print('Connecting to WebSocket for match ID: ${widget.match.id}');
    _webSocketService.connect(widget.match.id);

    // Subscribe to the message stream
    _webSocketSubscription = _webSocketService.messageStream.listen(
      (Map<String, dynamic> update) {
        _handleServerUpdate(update);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _reconnectWebSocket();
      },
      onDone: () {
        print('WebSocket connection closed');
        _reconnectWebSocket();
      },
    );
  }

  void _reconnectWebSocket() {
    // Attempt to reconnect after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _connectToWebSocket();
      }
    });
  }

  void _handleServerUpdate(Map<String, dynamic> update) {
    print('Received WebSocket update: $update');

    // Parse sound data
    if (update.containsKey('soundId')) {
      final int soundId = update['soundId'];
      final String title = update['title'] ?? '';
      final String soundUrl = update['soundUrl'] ?? '';
      final String? soundImageUrl = update['soundImageUrl'];
      final String status = update['status'] ?? 'STOPPED';
      final int currentMillisecond = update['currentMillisecond'] ?? 0;

      print(
        'WEBSOCKET UPDATE - soundId=$soundId, status=$status, position=$currentMillisecond',
      );

      // Process the sound immediately
      _processSound(
        soundId,
        title,
        soundUrl,
        soundImageUrl,
        status,
        currentMillisecond,
        update,
      );
    }
  }

  void _processSound(
    int soundId,
    String title,
    String soundUrl,
    String? soundImageUrl,
    String status,
    int currentMillisecond,
    Map<String, dynamic> update,
  ) {
    // Update tracking variables
    _lastSoundStatus = status;

    // CRITICAL: If this is a STOPPED or PAUSED command, block future playback
    if (status == 'STOPPED' || status == 'PAUSED') {
      print('CRITICAL: Received $status command - blocking future playback');
      _blockPlayback = true;
      _stopLocalTimer();
    }

    // Update local position tracking for STARTED or RESUMED
    if (status == 'STARTED' || status == 'RESUMED') {
      _startLocalTimer(currentMillisecond);
    }

    // Find sound in local storage
    Sound? matchingSound = _teamSounds.firstWhere(
      (s) => s.id == soundId,
      orElse: () => Sound(
        id: soundId,
        title: title,
        soundUrl: soundUrl,
        soundImageUrl: soundImageUrl,
        teamId: widget.match.teamId,
        teamName: widget.match.teamName,
        status: status,
        currentMillisecond: currentMillisecond,
        updatedAt: DateTime.now(),
        isDownloaded: false,
      ),
    );

    // Update UI state
    setState(() {
      _currentSound = matchingSound;
    });

    // Process sound based on status
    print('Processing sound status: $status');
    switch (status) {
      case 'STARTED':
        print('Starting sound from position: $currentMillisecond ms');
        // Reset the block flag when we receive a START command
        _blockPlayback = false;
        // Immediately play from the position received from WebSocket
        _forcePlaySoundFromStorage(matchingSound, currentMillisecond);
        break;

      case 'PAUSED':
        print('Pausing sound at position: $currentMillisecond ms');
        // Set the block flag to prevent future playback
        _blockPlayback = true;
        // First seek to the exact position, then pause
        _audioService.seek(Duration(milliseconds: currentMillisecond));
        _audioService.pause();
        break;

      case 'STOPPED':
        print('Stopping sound');
        // Set the block flag to prevent future playback
        _blockPlayback = true;
        // Aggressively stop the audio
        _audioService.stop();
        // Clear current sound to prevent auto-restart
        setState(() {
          _currentSound = null;
        });
        break;

      case 'RESUMED':
        print('Resuming sound from position: $currentMillisecond ms');
        // Reset the block flag
        _blockPlayback = false;
        // Always play from the position received from WebSocket
        _forcePlaySoundFromStorage(matchingSound, currentMillisecond);
        break;

      default:
        print('Unknown sound status: $status');
        break;
    }
  }

  // Start local timer to track position in real-time
  void _startLocalTimer(int initialMillisecond) {
    // Cancel any existing timers
    _stopLocalTimer();

    // Set initial values
    _localCurrentMillisecond = initialMillisecond;
    _lastReceivedMillisecond = initialMillisecond;
    _localTimerStartTime = DateTime.now();

    // Start a timer that updates the local position every 100ms
    _localPositionTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_lastSoundStatus == 'STARTED' || _lastSoundStatus == 'RESUMED') {
        final elapsedSinceStart = DateTime.now()
            .difference(_localTimerStartTime!)
            .inMilliseconds;
        _localCurrentMillisecond = _lastReceivedMillisecond + elapsedSinceStart;
      }
    });

    print('Local timer started at $_localCurrentMillisecond ms');
  }

  // Stop local timer
  void _stopLocalTimer() {
    _localPositionTimer?.cancel();
    _localPositionTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _localTimerStartTime = null;
    print('Local timer stopped');
  }

  // Schedule a sync after 5 seconds
  void _scheduleSyncAfter5Seconds(Sound sound) {
    _syncTimer?.cancel();
    _syncTimer = Timer(Duration(seconds: 5), () {
      if (mounted && _audioService.isPlaying.value && !_blockPlayback) {
        print('Syncing audio position with WebSocket after 5 seconds');
        print(
          'Local position: $_localCurrentMillisecond ms, WebSocket position: $_lastReceivedMillisecond ms',
        );

        // Only sync if the difference is significant (more than 500ms)
        final currentPosition = _audioService.position.value.inMilliseconds;
        final diff = (_localCurrentMillisecond - currentPosition).abs();
        if (diff > 500) {
          print(
            'Position difference is $diff ms, syncing to $_localCurrentMillisecond ms',
          );
          _audioService.seek(Duration(milliseconds: _localCurrentMillisecond));
        } else {
          print('Position difference is only $diff ms, no need to sync');
        }
      }
    });
  }

  // Force play sound from local storage, ignoring any block flags
  // This is used for STARTED and RESUMED commands from WebSocket
  Future<void> _forcePlaySoundFromStorage(Sound sound, int startPositionMs) async {
    // Get the local tracked position
    final localPosition = _localCurrentMillisecond > 0
        ? _localCurrentMillisecond
        : startPositionMs;
    print('Using local tracked position: $localPosition ms (WebSocket sent: $startPositionMs ms)');
    
    try {
      print('Playing sound from storage: ${sound.title} from position $localPosition ms');
      
      // Get the local file path
      final filePath = await _soundManager.getSoundFilePath(
        sound.teamId,
        sound.id,
      );
      
      // Load lyrics if available
      final lyrics = await _soundManager.getSoundLyrics(sound.teamId, sound.id);
      
      if (filePath != null) {
        // Force play the sound using the new method that completely resets the player
        await _audioService.forcePlayLocalAudio(filePath, startPositionMs: localPosition);
        
        // Update current sound and lyrics
        setState(() {
          _currentSound = sound;
          _currentLyrics = lyrics;
        });
      } else {
        print('ERROR: Could not find local file path for sound ${sound.id}');
      }
    } catch (e) {
      print('ERROR playing sound: $e');
    }
  }
  
  // Play sound from local storage with zero delay
  Future<void> _playSoundFromStorage(Sound sound, int startPositionMs) async {
    // CRITICAL: Check if playback is blocked before doing anything
    if (_blockPlayback || _lastSoundStatus == 'STOPPED') {
      print('PLAYBACK BLOCKED: Sound ${sound.id} has status $_lastSoundStatus');
      return;
    }

    // Use the local tracked position instead of the WebSocket position
    final actualStartPosition = _localCurrentMillisecond > 0
        ? _localCurrentMillisecond
        : startPositionMs;
    print(
      'Using local tracked position: $actualStartPosition ms (WebSocket sent: $startPositionMs ms)',
    );

    try {
      print(
        'Playing sound from storage: ${sound.title} from position $startPositionMs ms',
      );

      // First stop any currently playing audio
      await _audioService.stop();

      // Get the local file path
      final filePath = await _soundManager.getSoundFilePath(
        sound.teamId,
        sound.id,
      );

      if (filePath != null) {
        print('Found local file path: $filePath');

        // Play the audio file from the specified position with high priority
        await _audioService.playLocalAudio(
          filePath,
          startPositionMs: actualStartPosition,
        );

        // Schedule a sync after 5 seconds
        _scheduleSyncAfter5Seconds(sound);
      } else {
        print('Local sound file not found for sound ID: ${sound.id}');
        print('Attempting to sync team sounds...');

        // Try to sync team sounds which will download missing files
        await _soundManager.syncTeamSounds(sound.teamId);

        // Try to get the file path again after sync
        final syncedFilePath = await _soundManager.getSoundFilePath(
          sound.teamId,
          sound.id,
        );

        if (syncedFilePath != null) {
          print('Sound synced successfully, playing from: $syncedFilePath');
          await _audioService.playLocalAudio(
            syncedFilePath,
            startPositionMs: actualStartPosition,
          );

          // Schedule a sync after 5 seconds
          _scheduleSyncAfter5Seconds(sound);
        } else {
          print('Failed to sync sound file');
        }
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _webSocketSubscription?.cancel();
    _webSocketService.disconnect();
    _audioService.dispose();
    _localPositionTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.match.teamName} vs ${widget.match.getOpponentName()}'),
        backgroundColor: Colors.indigo[800],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Match Info Header
        _buildMatchInfoHeader(),
        
        // Sound controls and lyrics
        Expanded(
          child: Container(
            color: Colors.black87,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sound Card with Image, Title, Status
                  Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    color: Colors.grey[850],
                    child: Column(
                      children: [
                        // Sound image with status indicator
                        if (_currentSound != null) ...[                  
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              // Sound Image
                              FutureBuilder<String?>(
                                future: _currentSound!.soundImageUrl != null 
                                  ? _soundManager.getSoundImageFilePath(_currentSound!.teamId, _currentSound!.id)
                                  : Future.value(null),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    // Local image exists, load from file
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 250,
                                      child: Image.file(
                                        File(snapshot.data!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Error loading local image: $error');
                                          return _buildFallbackImage();
                                        },
                                      ),
                                    );
                                  } else if (_currentSound?.soundImageUrl != null) {
                                    // No local image but URL exists, try network image
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 250,
                                      child: Image.network(
                                        _currentSound!.soundImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Error loading network image: $error');
                                          return _buildFallbackImage();
                                        },
                                      ),
                                    );
                                  } else {
                                    // No image available
                                    return _buildFallbackImage();
                                  }
                                },
                              ),
                              
                              // Status Badge
                              Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_currentSound?.status).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _currentSound?.status == 'STARTED' || _currentSound?.status == 'RESUMED' 
                                        ? Icons.play_arrow 
                                        : _currentSound?.status == 'PAUSED' 
                                          ? Icons.pause 
                                          : Icons.stop,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentSound?.status ?? 'STOPPED',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Sound Info Section
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sound title
                              Text(
                                _currentSound?.title ?? 'No sound playing',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Sound position with progress indicator
                              ValueListenableBuilder<Duration>(
                                valueListenable: _audioService.position,
                                builder: (context, position, child) {
                                  final minutes = position.inMinutes;
                                  final seconds = (position.inSeconds % 60).toString().padLeft(2, '0');
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'KONUM',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white70,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          Text(
                                            '$minutes:$seconds',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // İlerleme çubuğu - sabit değer kullanıyoruz çünkü Sound modelinde durationMs yok
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: _currentSound != null 
                                            ? (position.inMilliseconds % 60000) / 60000 // 1 dakikalık döngü
                                            : 0,
                                          backgroundColor: Colors.grey[800],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _getStatusColor(_currentSound?.status)
                                          ),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Lyrics display section
                  _buildLyricsSection(),
                  
                  // WebSocket connection status
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _webSocketService.isConnected,
                      builder: (context, isConnected, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isConnected ? Colors.green : Colors.red,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isConnected ? Icons.wifi : Icons.wifi_off,
                                size: 18,
                                color: isConnected ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isConnected ? 'WebSocket Bağlı' : 'WebSocket Bağlantısı Yok',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Match info header widget
  Widget _buildMatchInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[800]!, Colors.indigo[600]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match title
          Text(
            '${widget.match.teamName} vs ${widget.match.getOpponentName()}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Match details
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                'Tarih: ${_formatDate(widget.match.matchDate)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.people, size: 16, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                'Takım: ${widget.match.teamName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Format date for display
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
  
  // Lyrics section widget
  Widget _buildLyricsSection() {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: Colors.grey[850],
      child: ValueListenableBuilder<Duration>(
        valueListenable: _audioService.position,
        builder: (context, position, child) {
          // Find current lyric based on position
          final currentSecond = position.inSeconds;
          final currentLyric = _findCurrentLyric(currentSecond);
          
          // Find next lyrics to display
          final sortedLyrics = List<Lyrics>.from(_currentLyrics!);
          sortedLyrics.sort((a, b) => a.second.compareTo(b.second));
          
          // Find current index and next lyrics
          int currentIndex = -1;
          if (currentLyric != null) {
            currentIndex = sortedLyrics.indexWhere((lyric) => lyric.id == currentLyric.id);
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lyrics header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[700]!, Colors.indigo[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ŞARKI SÖZLERİ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Current lyric with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  currentLyric?.lyric ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Next lyrics (preview)
              if (currentIndex >= 0 && currentIndex < sortedLyrics.length - 1)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    border: Border(
                      top: BorderSide(color: Colors.grey[800]!, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.indigo[400]!, width: 1),
                            ),
                            child: const Text(
                              'SONRAKI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${sortedLyrics[currentIndex + 1].second ~/ 60}:${(sortedLyrics[currentIndex + 1].second % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sortedLyrics[currentIndex + 1].lyric,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Position indicator at the bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    if (currentLyric != null) 
                      Text(
                        'Satır ${currentIndex + 1}/${sortedLyrics.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // Get status color based on sound status
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'STARTED':
      case 'RESUMED':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'STOPPED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Find the current lyric based on the current playback position
  Lyrics? _findCurrentLyric(int currentSecond) {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) {
      return null;
    }
    
    // Sort lyrics by second to ensure they're in order
    final sortedLyrics = List<Lyrics>.from(_currentLyrics!);
    sortedLyrics.sort((a, b) => a.second.compareTo(b.second));
    
    // Find the last lyric that should be displayed at the current time
    Lyrics? currentLyric;
    
    for (var lyric in sortedLyrics) {
      if (lyric.second <= currentSecond) {
        currentLyric = lyric;
      } else {
        // We've found a lyric that's in the future, so stop here
        break;
      }
    }
    
    return currentLyric;
  }
  
  // Fallback image widget when sound image is not available
  Widget _buildFallbackImage() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note,
        size: 80,
        color: Colors.white70,
      ),
    );
  }
}
