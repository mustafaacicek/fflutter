import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/lyrics.dart';
import '../models/match.dart';
import '../models/sound.dart';
import '../providers/api_provider.dart';
import '../services/audio_service.dart';
import '../services/sound_manager.dart';
import '../services/websocket_service.dart';
import '../utils/app_theme.dart';

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({Key? key, required this.match}) : super(key: key);

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Services
  late WebSocketService _webSocketService;
  late AudioService _audioService;
  late SoundManager _soundManager;
  late ApiProvider _apiProvider;

  // State variables
  List<Sound> _teamSounds = [];
  Sound? _currentSound;
  bool _showLyrics = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<Lyrics> _currentLyrics = [];

  // Special flag to track if we're returning from another screen
  bool _isReturningToScreen = false;
  DateTime? _lastActiveTime;
  Map<String, dynamic>? _lastWebSocketUpdate;
  
  // Sound control flags
  bool _blockPlayback = false;
  String _lastSoundStatus = '';
  int _lastSoundId = -1;

  // Animation controller for background
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    print('MatchDetailScreen - initState for match ${widget.match.id}');

    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _lastActiveTime = DateTime.now();

    // Initialize services
    _apiProvider = Provider.of<ApiProvider>(context, listen: false);
    _webSocketService = WebSocketService();
    _audioService = AudioService();
    _soundManager = SoundManager(apiProvider: _apiProvider);

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    // Initialize audio service
    _audioService.init().then((_) {
      print('Audio service initialized successfully');

      // Load team sounds
      _loadTeamSounds().then((_) {
        print('Team sounds loaded successfully');

        // Fetch current sound state after sounds are loaded
        _fetchCurrentSoundState();
      });
    });

    // Connect to WebSocket
    _connectToWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      final now = DateTime.now();
      final lastActive = _lastActiveTime ?? now;
      final difference = now.difference(lastActive).inSeconds;

      print('App resumed after $difference seconds');

      if (difference > 1) {
        // If we've been away for more than 1 second, consider it a return to the screen
        _isReturningToScreen = true;
        print('Detected return to MatchDetailScreen, forcing sound check');

        // Force reconnect WebSocket
        _connectToWebSocket();

        // Force sound check with delay to ensure WebSocket is connected
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _forcePlayCurrentSound();
          }
        });
      }

      _lastActiveTime = now;
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _lastActiveTime = DateTime.now();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print(
      'MatchDetailScreen - didChangeDependencies for match ${widget.match.id}',
    );

    // Set returning flag to true
    _isReturningToScreen = true;

    // Force check and play current sound when returning to the screen
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        print('DIRECT NAVIGATION DETECTED - Forcing sound check');
        _forcePlayCurrentSound();
      }
    });
  }

  @override
  void dispose() {
    print('Disposing match detail screen for match ${widget.match.id}');
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    // Disconnect WebSocket
    _webSocketService.disconnect();
    // Dispose audio service
    _audioService.dispose();
    // Dispose animation controller
    _animationController.dispose();
    super.dispose();
  }

  // Force play current sound - special method to handle returning to screen
  Future<void> _forcePlayCurrentSound() async {
    print(
      '!!!!! FORCE PLAYING CURRENT SOUND - EMERGENCY HANDLING FOR SCREEN RETURN !!!!!',
    );

    try {
      // First completely reinitialize audio service
      await _audioService.stop();
      await _audioService.init();
      print('Audio service reinitialized for force play');

      // Make direct API call regardless of last update
      print('Making direct API call to fetch current sound state');
      final response = await _apiProvider.fetchMatchSoundState(widget.match.id);
      print('!!!!! FORCE CHECK - Received sound state: $response');

      if (response != null && response.containsKey('soundId')) {
        final int soundId = response['soundId'];
        final String status = response['status'] ?? 'STOPPED';
        final int currentMillisecond = response['currentMillisecond'] ?? 0;
        final String title = response['title'] ?? '';
        final String soundUrl = response['soundUrl'] ?? '';
        final String? soundImageUrl = response['soundImageUrl'];

        print(
          '!!!!! FORCE CHECK - Sound data: ID=$soundId, status=$status, position=$currentMillisecond',
        );

        // Force sound to play regardless of status for testing
        print(
          '!!!!! FORCE CHECK - FORCING SOUND PLAYBACK REGARDLESS OF STATUS',
        );

        // Make sure team sounds are loaded
        if (_teamSounds.isEmpty) {
          print(
            '!!!!! FORCE CHECK - Team sounds not loaded, loading them first',
          );
          await _loadTeamSounds();
        }

        // Find the sound
        Sound? matchingSound = _teamSounds.firstWhere(
          (s) => s.id == soundId,
          orElse: () => Sound(
            id: soundId,
            title: title,
            soundUrl: soundUrl,
            soundImageUrl: soundImageUrl,
            teamId: widget.match.teamId,
            teamName: widget.match.teamName,
            status: 'STARTED', // Force status to STARTED
            currentMillisecond: currentMillisecond,
            updatedAt: DateTime.now(),
            isDownloaded: false,
          ),
        );

        print(
          '!!!!! FORCE CHECK - Playing sound: ${matchingSound.title} from $currentMillisecond ms',
        );

        // Get the file path
        final filePath = await _soundManager.getSoundFilePath(
          matchingSound.teamId,
          matchingSound.id,
        );

        if (filePath != null) {
          print('!!!!! FORCE CHECK - Found file path: $filePath');

          // Play directly using audio service for maximum reliability
          await _audioService.playLocalAudio(
            filePath,
            startPositionMs: currentMillisecond,
          );

          // Update UI state
          setState(() {
            _currentSound = matchingSound;
          });

          // Double-check playback after a delay
          Future.delayed(Duration(milliseconds: 1000), () async {
            final isActuallyPlaying = _audioService.isPlaying.value;
            print(
              '!!!!! FORCE CHECK - Is sound actually playing after 1 second? $isActuallyPlaying',
            );

            if (!isActuallyPlaying) {
              print(
                '!!!!! FORCE CHECK - Sound not playing, trying one more time',
              );
              await _audioService.playLocalAudio(
                filePath,
                startPositionMs: currentMillisecond,
              );
            }
          });
        } else {
          print(
            '!!!!! FORCE CHECK - File path not found, trying to sync sounds',
          );
          await _soundManager.syncTeamSounds(matchingSound.teamId);

          // Try again after sync
          final syncedFilePath = await _soundManager.getSoundFilePath(
            matchingSound.teamId,
            matchingSound.id,
          );

          if (syncedFilePath != null) {
            print(
              '!!!!! FORCE CHECK - Found file path after sync: $syncedFilePath',
            );
            await _audioService.playLocalAudio(
              syncedFilePath,
              startPositionMs: currentMillisecond,
            );

            setState(() {
              _currentSound = matchingSound;
            });
          } else {
            print('!!!!! FORCE CHECK - Still cannot find file path after sync');
          }
        }

        // Reset the returning flag
        _isReturningToScreen = false;
      } else {
        print('!!!!! FORCE CHECK - No sound state available from API');

        // Try using last WebSocket update as fallback
        if (_lastWebSocketUpdate != null &&
            _lastWebSocketUpdate!.containsKey('soundId')) {
          print(
            '!!!!! FORCE CHECK - Using last WebSocket update as fallback: $_lastWebSocketUpdate',
          );

          final int soundId = _lastWebSocketUpdate!['soundId'];
          final String title = _lastWebSocketUpdate!['title'] ?? '';
          final String soundUrl = _lastWebSocketUpdate!['soundUrl'] ?? '';
          final String? soundImageUrl = _lastWebSocketUpdate!['soundImageUrl'];
          final int currentMillisecond =
              _lastWebSocketUpdate!['currentMillisecond'] ?? 0;

          // Use the original status from the WebSocket update
          final String originalStatus = _lastWebSocketUpdate!['status'] ?? 'STOPPED';
          print('!!!!! FORCE CHECK - Using original status: $originalStatus');
          
          // Set the block flag if the status is STOPPED or PAUSED
          if (originalStatus == 'STOPPED' || originalStatus == 'PAUSED') {
            _blockPlayback = true;
          }
          
          // Only process if the status is not STOPPED or PAUSED
          if (originalStatus == 'STOPPED' || originalStatus == 'PAUSED') {
            print('!!!!! FORCE CHECK - Not playing sound because status is $originalStatus');
            // Just update the UI to show the correct status
            setState(() {
              _currentSound = Sound(
                id: soundId,
                title: title,
                soundUrl: soundUrl,
                soundImageUrl: soundImageUrl,
                teamId: widget.match.teamId,
                teamName: widget.match.teamName,
                status: originalStatus,
                currentMillisecond: currentMillisecond,
                updatedAt: DateTime.now(),
                isDownloaded: true,
              );
            });
            
            // Make sure audio is completely stopped
            _audioService.stop();
            Future.delayed(Duration(milliseconds: 100), () {
              _audioService.init();
            });
          } else {
            // Only process the sound if it's not stopped or paused
            _processSound(
              soundId,
              title,
              soundUrl,
              soundImageUrl,
              originalStatus, // Use the original status
              currentMillisecond,
              _lastWebSocketUpdate!,
            );
          }
        }
      }
    } catch (e) {
      print('!!!!! FORCE CHECK - Error forcing sound playback: $e');
      print('!!!!! FORCE CHECK - Stack trace: ${StackTrace.current}');
    }
  }

  // Fetch current sound state from server
  Future<void> _fetchCurrentSoundState() async {
    print('Fetching current sound state for match ${widget.match.id}');

    try {
      // First make sure team sounds are loaded
      if (_teamSounds.isEmpty) {
        print('Team sounds not loaded yet, loading them first');
        await _loadTeamSounds();
      }

      // Make API request to get current sound state
      final response = await _apiProvider.fetchMatchSoundState(widget.match.id);
      print('Received sound state response: $response');

      if (response != null && response.containsKey('soundId')) {
        final int soundId = response['soundId'];
        final String status = response['status'] ?? 'STOPPED';
        final int currentMillisecond = response['currentMillisecond'] ?? 0;
        final String title = response['title'] ?? '';
        final String soundUrl = response['soundUrl'] ?? '';
        final String? soundImageUrl = response['soundImageUrl'];

        print(
          'Current sound state: soundId=$soundId, status=$status, position=$currentMillisecond',
        );

        // Find the sound in the loaded sounds
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

        // Parse lyrics if available
        List<Lyrics> lyrics = [];
        if (response.containsKey('lyrics') && response['lyrics'] is List) {
          final List<dynamic> lyricsData = response['lyrics'];
          lyrics = lyricsData.map((item) {
            return Lyrics(
              id: item['id'] ?? 0,
              lyric: item['lyric'] ?? '',
              second: item['second'] ?? 0,
            );
          }).toList();
          lyrics.sort((a, b) => a.second.compareTo(b.second));

          // Update lyrics in audio service
          _audioService.setLyrics(lyrics);

          setState(() {
            _currentLyrics = lyrics;
          });
        }

        if (status == 'STARTED') {
          print(
            'Found active sound: ${matchingSound.title}, playing from $currentMillisecond ms',
          );
          // Play the sound from the current position
          await _playSoundFromStorage(matchingSound, currentMillisecond);

          setState(() {
            _currentSound = matchingSound;
          });
        }
      } else {
        print('No active sound for this match');
      }
    } catch (e) {
      print('Error fetching sound state: $e');
    }
  }

  // Load team sounds from storage
  Future<void> _loadTeamSounds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get stored sounds for team
      final sounds = await _apiProvider.getStoredSounds(widget.match.teamId);
      setState(() {
        _teamSounds = sounds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sesler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  // Connect to WebSocket with retry logic
  void _connectToWebSocket() {
    // First disconnect any existing connection
    _webSocketService.disconnect();

    // Connect to WebSocket for this match
    print('Connecting to WebSocket for match ${widget.match.id}');
    _webSocketService.connect(widget.match.id);

    // Listen for WebSocket messages
    _webSocketService.messageStream.listen((data) {
      if (mounted) {
        _handleServerUpdate(data);
      }
    });

    // Check connection status after a delay and retry if needed
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_webSocketService.isConnected.value) {
        print('WebSocket connection failed, retrying...');
        _webSocketService.connect(widget.match.id);
      }
    });
  }

  // Handle WebSocket updates from server
  void _handleServerUpdate(Map<String, dynamic> update) {
    print('Received WebSocket update: $update');

    // Store the last WebSocket update for use when returning to the screen
    _lastWebSocketUpdate = Map<String, dynamic>.from(update);

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

      // First check if we have the team sounds loaded
      if (_teamSounds.isEmpty) {
        print('Team sounds not loaded yet, loading them first');
        _loadTeamSounds().then((_) {
          // Once sounds are loaded, process the update again
          _processSound(
            soundId,
            title,
            soundUrl,
            soundImageUrl,
            status,
            currentMillisecond,
            update,
          );
        });
        return;
      }

      // If we're returning to the screen and this is a STARTED status, force immediate playback
      if (_isReturningToScreen && status == 'STARTED') {
        print(
          'RETURNING TO SCREEN - Forcing immediate sound playback from WebSocket update',
        );
        _isReturningToScreen = false; // Reset the flag

        // Process the sound with high priority
        _processSound(
          soundId,
          title,
          soundUrl,
          soundImageUrl,
          status,
          currentMillisecond,
          update,
        );
        return;
      }

      // Process the sound directly if sounds are already loaded
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

  // Process sound data from WebSocket update
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
    _lastSoundId = soundId;

    // CRITICAL: If this is a STOPPED or PAUSED command, block future playback
    if (status == 'STOPPED' || status == 'PAUSED') {
      print('CRITICAL: Received $status command - blocking future playback');
      _blockPlayback = true;
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

    // Parse lyrics if available
    List<Lyrics> lyrics = [];
    if (update.containsKey('lyrics') && update['lyrics'] is List) {
      final List<dynamic> lyricsData = update['lyrics'];
      lyrics = lyricsData.map((item) {
        return Lyrics(
          id: item['id'] ?? 0,
          lyric: item['lyric'] ?? '',
          second: item['second'] ?? 0,
        );
      }).toList();
      lyrics.sort((a, b) => a.second.compareTo(b.second));
    }

    // Update UI state
    setState(() {
      _currentSound = matchingSound;
      _currentLyrics = lyrics;
    });

    // Update lyrics in audio service
    _audioService.setLyrics(lyrics);

    // Process sound based on status
    print('Processing sound status: $status');
    switch (status) {
      case 'STARTED':
        print('Starting sound from position: $currentMillisecond ms');
        // Reset the block flag when we receive a START command
        _blockPlayback = false;
        // Always play from the position received from WebSocket
        _playSoundFromStorage(matchingSound, currentMillisecond);
        break;

      case 'PAUSED':
        print('Pausing sound at position: $currentMillisecond ms');
        // Set the block flag to prevent future playback
        _blockPlayback = true;
        // First seek to the exact position, then pause
        _audioService.seek(Duration(milliseconds: currentMillisecond));
        _audioService.pause();
        // Reinitialize the audio service to ensure complete stop
        Future.delayed(Duration(milliseconds: 100), () {
          _audioService.init();
        });
        break;

      case 'STOPPED':
        print('Stopping sound');
        // Set the block flag to prevent future playback
        _blockPlayback = true;
        // Aggressively stop the audio
        _audioService.stop();
        // Reinitialize the audio service to ensure complete stop
        Future.delayed(Duration(milliseconds: 100), () {
          _audioService.init();
        });
        break;

      case 'RESUMED':
        print('Resuming sound from position: $currentMillisecond ms');
        // Always play from the position received from WebSocket
        _playSoundFromStorage(matchingSound, currentMillisecond);
        break;

      default:
        print('Unknown sound status: $status');
        break;
    }
  }

  // Play sound from local storage
  Future<void> _playSoundFromStorage(Sound sound, int startPositionMs) async {
    // CRITICAL: Check if playback is blocked before doing anything
    if (_blockPlayback) {
      print('PLAYBACK BLOCKED: Sound ${sound.id} has status $_lastSoundStatus');
      return;
    }

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

        // Play the audio file from the specified position
        await _audioService.playLocalAudio(
          filePath,
          startPositionMs: startPositionMs,
        );

        // Verify that audio is actually playing
        Future.delayed(const Duration(milliseconds: 500), () {
          // Check if playback is still allowed
          if (_blockPlayback) {
            print('PLAYBACK BLOCKED DURING VERIFICATION: Stopping playback');
            _audioService.stop();
            return;
          }

          if (mounted) {
            final position = _audioService.position.value.inMilliseconds;
            print('Audio position after 500ms: $position ms');

            // Only retry if playback is still allowed
            if (!_blockPlayback && (position < startPositionMs || position > startPositionMs + 1000)) {
              print('Audio position mismatch, retrying playback');
              _audioService.playLocalAudio(
                filePath,
                startPositionMs: startPositionMs,
              );
            }
          }
        });

        // Update current sound in UI
        setState(() {
          _currentSound = sound;
        });
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
            startPositionMs: startPositionMs,
          );

          // Update current sound in UI
          setState(() {
            _currentSound = sound;
          });
        } else {
          print('Failed to sync sound file');
        }
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Toggle lyrics view
  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  // Change current sound
  void _changeSound(Sound sound) {
    setState(() {
      _currentSound = sound;
    });

    // Play sound if it's downloaded
    if (sound.isDownloaded) {
      _playSoundFromStorage(sound, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          '${widget.match.teamName} vs ${widget.match.getOpponentName()}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.3),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.3),
              child: IconButton(
                icon: Icon(
                  _showLyrics ? Icons.music_note : Icons.lyrics,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleLyrics,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.8),
                      AppTheme.backgroundColor.withOpacity(0.9),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: [0.0, 0.5 + (_animation.value * 0.2), 1.0],
                  ),
                ),
              );
            },
          ),

          // Match info at top
          Positioned(
            top: 20, // AppBar altında biraz daha fazla mesafe
            left: 0,
            right: 0,
            child: _buildMatchInfo(),
          ),

          // Main content - either lyrics or sound list
          Positioned(
            top: 180, // Maç bilgisinin altında çok daha fazla boşluk bırak
            left: 0,
            right: 0,
            bottom: 80, // Player kontrollerinin üstünde boşluk bırak
            child: _showLyrics ? _buildLyricsView() : _buildSoundListView(),
          ),

          // Player controls at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPlayerControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home team
          Column(
            children: [
              _buildTeamLogo(widget.match.teamLogo),
              const SizedBox(height: 8),
              Text(
                widget.match.teamName,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.match.getScoreText(),
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),

          // Away team
          Column(
            children: [
              _buildTeamLogo(widget.match.getOpponentLogo()),
              const SizedBox(height: 8),
              Text(
                widget.match.getOpponentName(),
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[600]!, width: 2),
        ),
        child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 30),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(
          logoUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Colors.white70,
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Şarkı Sözleri",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _toggleLyrics,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _currentLyrics.isEmpty
                ? Center(
                    child: Text(
                      "Bu ses için şarkı sözü bulunmuyor",
                      style: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ValueListenableBuilder<String?>(
                    valueListenable: _audioService.currentLyric,
                    builder: (context, currentLyric, child) {
                      return ListView.builder(
                        itemCount: _currentLyrics.length,
                        itemBuilder: (context, index) {
                          final lyric = _currentLyrics[index];
                          final isCurrentLyric = lyric.lyric == currentLyric;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              lyric.lyric,
                              style: GoogleFonts.montserrat(
                                color: isCurrentLyric
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                                fontSize: isCurrentLyric ? 18 : 16,
                                fontWeight: isCurrentLyric
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                height: 1.5,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
      );
    }

    if (_teamSounds.isEmpty) {
      return Center(
        child: Text(
          "Bu takım için ses bulunamadı",
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _teamSounds.length,
      itemBuilder: (context, index) {
        final sound = _teamSounds[index];
        final isActive = _currentSound?.id == sound.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? AppTheme.primaryColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _changeSound(sound),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Sound image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(
                            sound.soundImageUrl ??
                                'https://picsum.photos/id/1/200/200',
                          ),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) => const AssetImage(
                            'assets/images/default_sound.png',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sound info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sound.title,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Ses Dosyası", // Placeholder text
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Download status
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sound.isDownloaded
                            ? Colors.green
                            : Colors.grey.withOpacity(0.5),
                      ),
                      child: Icon(
                        sound.isDownloaded ? Icons.check : Icons.download,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerControls() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress indicator (non-interactive)
              ValueListenableBuilder<Duration>(
                valueListenable: _audioService.position,
                builder: (context, position, child) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: _audioService.duration,
                    builder: (context, duration, child) {
                      final progress = duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0;

                      return Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.grey[700],
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Time indicators
              const SizedBox(height: 8),
              ValueListenableBuilder<Duration>(
                valueListenable: _audioService.position,
                builder: (context, position, child) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: _audioService.duration,
                    builder: (context, duration, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position.inSeconds),
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          ValueListenableBuilder<String?>(
                            valueListenable: _audioService.currentLyric,
                            builder: (context, currentLyric, child) {
                              return Text(
                                currentLyric ?? '',
                                style: GoogleFonts.montserrat(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          Text(
                            _formatDuration(duration.inSeconds),
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format duration to MM:SS
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
