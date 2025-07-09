import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/just_audio.dart' show AudioSource;
import 'package:flutter/foundation.dart';
import '../models/lyrics.dart';

class AudioService {
  // Make _audioPlayer non-final so we can recreate it when needed
  AudioPlayer _audioPlayer = AudioPlayer();

  // Singleton pattern
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  // Audio state notifiers
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<String?> currentLyric = ValueNotifier<String?>(null);
  final ValueNotifier<List<Lyrics>> lyrics = ValueNotifier<List<Lyrics>>([]);

  // Stream subscriptions
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Timer? _lyricTimer;

  // Initialize audio player
  Future<void> init() async {
    try {
      print('AUDIO SERVICE: Initializing audio service');

      // Dispose existing player and create a new one
      _playerStateSubscription?.cancel();
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      await _audioPlayer.dispose();
      _audioPlayer = AudioPlayer();

      // Reset state values
      isPlaying.value = false;
      position.value = Duration.zero;
      duration.value = Duration.zero;
      currentLyric.value = null;

      // Listen for player state changes
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        isPlaying.value = state.playing;
        print(
          'AUDIO SERVICE: Player state changed - playing: ${state.playing}',
        );
      });

      // Listen for position changes
      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        position.value = pos;
        // Only log position changes occasionally to avoid log spam
        if (pos.inMilliseconds % 1000 < 50) {
          print('AUDIO SERVICE: Position updated: ${pos.inMilliseconds} ms');
        }
        _updateCurrentLyric();
      });

      // Listen for duration changes
      _durationSubscription = _audioPlayer.durationStream.listen((dur) {
        if (dur != null) {
          duration.value = dur;
          print('AUDIO SERVICE: Duration set: ${dur.inMilliseconds} ms');
        }
      });

      // Listen for errors
      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          print('AUDIO SERVICE: Audio player error: $e');
          // Try to recover from error
          _recoverFromError();
        },
      );

      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);

      print('AUDIO SERVICE: Audio service initialized successfully');
    } catch (e) {
      print('AUDIO SERVICE: Error initializing audio service: $e');
      // Try to recover
      _recoverFromError();
    }
  }

  // Attempt to recover from errors
  Future<void> _recoverFromError() async {
    try {
      print('AUDIO SERVICE: Attempting to recover from error');
      await _audioPlayer.dispose();
      _audioPlayer = AudioPlayer();

      // Reinitialize listeners
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        isPlaying.value = state.playing;
      });

      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        position.value = pos;
        _updateCurrentLyric();
      });

      _durationSubscription = _audioPlayer.durationStream.listen((dur) {
        if (dur != null) {
          duration.value = dur;
        }
      });

      print('AUDIO SERVICE: Recovery successful');
    } catch (e) {
      print('AUDIO SERVICE: Recovery failed: $e');
    }
  }

  // Play audio from local file
  // Regular play method - this may be affected by stop/pause state
  Future<void> playLocalAudio(
    String filePath, {
    int startPositionMs = 0,
  }) async {
    try {
      print(
        'AUDIO SERVICE: Playing local audio from $filePath at position $startPositionMs ms',
      );

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('AUDIO SERVICE: Audio file not found: $filePath');
        return;
      }

      // Set the audio source
      print('AUDIO SERVICE: Setting file path: $filePath');
      await _audioPlayer.setFilePath(filePath);

      // Seek to position if needed
      if (startPositionMs > 0) {
        print('AUDIO SERVICE: Seeking to position: $startPositionMs ms');
        await _audioPlayer.seek(Duration(milliseconds: startPositionMs));
      }

      // Start playback
      print('AUDIO SERVICE: Starting playback');
      await _audioPlayer.play();

      print(
        'AUDIO SERVICE: Started playing from position: $startPositionMs ms',
      );
    } catch (e) {
      print('AUDIO SERVICE: Error playing audio: $e');
    }
  }

  // Play audio from URL
  Future<void> playFromUrl(String url, {int startPositionMs = 0}) async {
    try {
      print('Setting URL audio source: $url');

      // Check if we're already playing this URL
      final currentUrl =
          _audioPlayer.sequenceState?.currentSource?.tag as String?;
      final isCurrentSource = currentUrl == url;

      if (!isCurrentSource) {
        // Set new audio source if it's different
        print('Setting new URL source: $url');
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(url), tag: url),
        );
      } else {
        print('Already playing this URL, just seeking to position');
      }

      // Seek to position if needed
      if (startPositionMs > 0) {
        print('Seeking to position: $startPositionMs ms');
        await _audioPlayer.seek(Duration(milliseconds: startPositionMs));
      }

      // Start playback
      await _audioPlayer.play();
      print('Started playing from URL');
    } catch (e) {
      print('Error playing audio from URL: $e');
    }
  }

  // Set lyrics for the current audio
  void setLyrics(List<Lyrics> newLyrics) {
    lyrics.value = List<Lyrics>.from(newLyrics)
      ..sort((a, b) => a.second.compareTo(b.second));
    _updateCurrentLyric();
  }

  // Update current lyric based on position
  void _updateCurrentLyric() {
    if (lyrics.value.isEmpty) {
      currentLyric.value = null;
      return;
    }

    final currentPositionSeconds = position.value.inSeconds;
    String? lyricText;

    // Find the lyric that should be displayed at the current position
    for (int i = lyrics.value.length - 1; i >= 0; i--) {
      if (lyrics.value[i].second <= currentPositionSeconds) {
        lyricText = lyrics.value[i].lyric;
        break;
      }
    }

    currentLyric.value = lyricText;
  }

  // Play, pause, seek methods
  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    try {
      print('AUDIO SERVICE: Pausing playback');
      await _audioPlayer.pause();
      
      // Kesinlikle duraklatıldığından emin ol
      if (isPlaying.value) {
        print('AUDIO SERVICE: Forcing pause again');
        await _audioPlayer.pause();
        
        // Hala çalıyorsa, daha agresif bir yaklaşım dene
        if (isPlaying.value) {
          print('AUDIO SERVICE: Still playing, trying stop without reset');
          await _audioPlayer.stop();
          
          // Pozisyonu koru
          final currentPos = position.value;
          if (currentPos.inMilliseconds > 0) {
            await _audioPlayer.seek(currentPos);
            print('AUDIO SERVICE: Restored position to ${currentPos.inMilliseconds} ms after stop');
          }
        }
      }
      
      print('AUDIO SERVICE: Playback paused');
    } catch (e) {
      print('AUDIO SERVICE: Error pausing playback: $e');
    }
  }

  // Method to force play a local audio file regardless of current state
  Future<void> forcePlayLocalAudio(String filePath, {int startPositionMs = 0}) async {
    print('AUDIO SERVICE: Force playing local audio from $filePath at position $startPositionMs ms');
    try {
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('AUDIO SERVICE: Audio file not found: $filePath');
        return;
      }
      
      // Önce dinleyicileri iptal et (MediaCodec hatalarını önlemek için)
      _playerStateSubscription?.cancel();
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription = null;
      _positionSubscription = null;
      _durationSubscription = null;
      
      try {
        // Completely dispose and recreate the audio player
        if (_audioPlayer != null) {
          await _audioPlayer.stop();
          await _audioPlayer.dispose();
        }
      } catch (disposeError) {
        print('AUDIO SERVICE: Error disposing player: $disposeError');
        // Hata yutuldu, devam ediyoruz
      }
      
      // Yeni oynatıcı oluştur
      try {
        _audioPlayer = AudioPlayer();
        
        // Yeni dinleyiciler ekle - hata yakalama ekleyerek
        _playerStateSubscription = _audioPlayer.playerStateStream.listen(
          (state) {
            isPlaying.value = state.playing;
            print('AUDIO SERVICE: Player state changed - playing: ${state.playing}');
          },
          onError: (e, stackTrace) {
            print('AUDIO SERVICE: Player state stream error: $e');
            // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
          },
        );
        
        _positionSubscription = _audioPlayer.positionStream.listen(
          (pos) {
            position.value = pos;
            if (pos.inMilliseconds % 1000 < 50) {
              print('AUDIO SERVICE: Position updated: ${pos.inMilliseconds} ms');
            }
            _updateCurrentLyric();
          },
          onError: (e, stackTrace) {
            print('AUDIO SERVICE: Position stream error: $e');
            // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
          },
        );
        
        _durationSubscription = _audioPlayer.durationStream.listen(
          (dur) {
            if (dur != null) {
              duration.value = dur;
              print('AUDIO SERVICE: Duration set: ${dur.inMilliseconds} ms');
            }
          },
          onError: (e, stackTrace) {
            print('AUDIO SERVICE: Duration stream error: $e');
            // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
          },
        );
        
        // Set the audio source
        print('AUDIO SERVICE: Setting file path: $filePath');
        await _audioPlayer.setFilePath(filePath);
        
        // Seek to position if needed
        if (startPositionMs > 0) {
          print('AUDIO SERVICE: Seeking to position: $startPositionMs ms');
          await _audioPlayer.seek(Duration(milliseconds: startPositionMs));
        }
        
        // STARTED durumunda her zaman çalmaya başla
        print('AUDIO SERVICE: Starting playback');
        await _audioPlayer.play();
        print('AUDIO SERVICE: Started playing from position: $startPositionMs ms');
      } catch (setupError) {
        print('AUDIO SERVICE: Error setting up player: $setupError');
        // Hata durumunda oynatıcıyı temizlemeye çalış
        try {
          if (_audioPlayer != null) {
            await _audioPlayer.dispose();
          }
          _audioPlayer = AudioPlayer(); // Yeni temiz bir oynatıcı oluştur
        } catch (e2) {
          print('AUDIO SERVICE: Error cleaning up after setup failure: $e2');
        }
      }
    } catch (e) {
      print('AUDIO SERVICE: Error force playing audio: $e');
    } finally {
      // Oynatıcı durumunu UI'da güncelle
      if (_audioPlayer != null) {
        isPlaying.value = _audioPlayer.playing;
      } else {
        isPlaying.value = false;
      }
    }
  }
  
  Future<void> stop() async {
    print('AUDIO SERVICE: Stopping playback');
    
    // Önce dinleyicileri iptal et (hata mesajlarını önlemek için)
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;
    
    try {
      // Önce durdur
      if (_audioPlayer != null) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      print('AUDIO SERVICE: Error stopping player: $e');
      // Hata yutuldu, devam ediyoruz
    }
    
    // Pozisyonu sıfırla
    position.value = Duration.zero;
    
    try {
      // Oynatıcıyı temizle
      if (_audioPlayer != null) {
        await _audioPlayer.dispose();
      }
    } catch (e) {
      print('AUDIO SERVICE: Error disposing player: $e');
      // Hata yutuldu, devam ediyoruz
    }
    
    // Yeni oynatıcı oluştur
    try {
      _audioPlayer = AudioPlayer();
      
      // Yeni dinleyiciler ekle
      _playerStateSubscription = _audioPlayer.playerStateStream.listen(
        (state) {
          isPlaying.value = state.playing;
          print('AUDIO SERVICE: Player state changed - playing: ${state.playing}');
        },
        onError: (e, stackTrace) {
          print('AUDIO SERVICE: Player state stream error: $e');
          // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
        },
      );

      _positionSubscription = _audioPlayer.positionStream.listen(
        (pos) {
          position.value = pos;
          _updateCurrentLyric();
        },
        onError: (e, stackTrace) {
          print('AUDIO SERVICE: Position stream error: $e');
          // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
        },
      );

      _durationSubscription = _audioPlayer.durationStream.listen(
        (dur) {
          if (dur != null) {
            duration.value = dur;
          }
        },
        onError: (e, stackTrace) {
          print('AUDIO SERVICE: Duration stream error: $e');
          // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
        },
      );
      
      print('AUDIO SERVICE: Player recreated successfully');
    } catch (e) {
      print('AUDIO SERVICE: Error recreating player: $e');
    }
    
    // Son olarak, oynatıcının kesinlikle durdurulduğundan emin ol
    isPlaying.value = false;
    print('AUDIO SERVICE: Playback stopped completely');
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // Ses dosyasını önceden hafızaya yükler, böylece çalma anında gecikme olmaz
  Future<void> preloadAudioFile(String filePath) async {
    AudioPlayer? preloadPlayer;
    try {
      // Dosyanın varlığını kontrol et
      final file = File(filePath);
      if (!await file.exists()) {
        print('AUDIO SERVICE: File does not exist: $filePath');
        return;
      }
      
      // Just_audio'nun ön yükleme özelliğini kullan
      preloadPlayer = AudioPlayer();
      
      // Hata durumunda dinleyici ekle
      preloadPlayer.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace stackTrace) {
          print('AUDIO SERVICE: Preload error handled: $e');
          // Hata dinleyicisi ekleyerek hataların uygulama çökmesine neden olmasını engelliyoruz
        },
        onDone: () {
          print('AUDIO SERVICE: Preload stream done');
        },
      );
      
      // Dosyayı yükle
      await preloadPlayer.setFilePath(filePath);
      
      print('AUDIO SERVICE: Preloaded audio file: $filePath');
    } catch (e) {
      print('AUDIO SERVICE: Error preloading audio file: $e');
    } finally {
      // Her durumda kaynakları temizle
      try {
        if (preloadPlayer != null) {
          await preloadPlayer.stop();
          await preloadPlayer.dispose();
          preloadPlayer = null;
        }
      } catch (disposeError) {
        print('AUDIO SERVICE: Error disposing preload player: $disposeError');
      }
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    print('AUDIO SERVICE: Disposing resources');
    
    // Dinleyicileri iptal et
    try {
      _playerStateSubscription?.cancel();
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _lyricTimer?.cancel();
      
      _playerStateSubscription = null;
      _positionSubscription = null;
      _durationSubscription = null;
      _lyricTimer = null;
    } catch (e) {
      print('AUDIO SERVICE: Error canceling subscriptions: $e');
    }
    
    // Oynatıcıyı durdur ve temizle
    try {
      if (_audioPlayer != null) {
        await _audioPlayer.stop();
        await _audioPlayer.dispose();
      }
    } catch (e) {
      print('AUDIO SERVICE: Error disposing audio player: $e');
    }
    
    print('AUDIO SERVICE: All resources disposed');
  }
}
