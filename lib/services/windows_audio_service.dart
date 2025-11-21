import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import 'scraping_service.dart';

/// Windows-specific audio service that uses just_audio directly
/// without the audio_service package (which doesn't support Windows)
class WindowsAudioService {
  static final WindowsAudioService _instance = WindowsAudioService._internal();
  factory WindowsAudioService() => _instance;
  WindowsAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  RadioStation? _currentStation;
  bool _isInitialized = false;

  // Stream getters for UI to listen to
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<double> get volumeStream => _audioPlayer.volumeStream;

  bool get isPlaying => _audioPlayer.playing;
  RadioStation? get currentStation => _currentStation;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Windows audio service already initialized');
      return;
    }

    print('🔧 Initializing Windows audio service...');

    // Set up audio player for streaming
    await _audioPlayer.setVolume(1.0);

    _isInitialized = true;
    print('✅ Windows audio service initialized');
  }

  Future<void> playRadioStation(RadioStation station) async {
    try {
      print('🎵 Windows: Playing station: ${station.name}');
      print('🎵 Windows: Station URL: ${station.url}');
      _currentStation = station;

      String actualStreamUrl = station.url;

      // If the URL is a play page, resolve it to actual streaming URL
      if (station.url.contains('/play/') && !station.url.contains('.m3u') && !station.url.contains('.pls')) {
        print('🔍 Windows: Resolving streaming URL from play page...');
        try {
          final resolvedUrl = await ScrapingService.getStreamUrlFromPlayPage(station.url)
              .timeout(const Duration(seconds: 15));
          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            actualStreamUrl = resolvedUrl;
            print('✅ Windows: Resolved streaming URL: $actualStreamUrl');
          } else {
            throw Exception('Could not resolve streaming URL for ${station.name}');
          }
        } catch (e) {
          print('❌ Windows: Failed to resolve stream URL: $e');
          throw Exception('Failed to get stream URL: $e');
        }
      }

      print('🎵 Windows: Setting audio URL: $actualStreamUrl');

      try {
        await _audioPlayer.setUrl(actualStreamUrl).timeout(const Duration(seconds: 20));
        print('✅ Windows: Audio URL set successfully');
      } catch (e) {
        print('❌ Windows: Failed to set audio URL: $e');
        throw Exception('Failed to load audio stream: $e');
      }

      print('▶️  Windows: Starting playback...');
      try {
        await _audioPlayer.play();
        print('✅ Windows: Playback started successfully');
      } catch (e) {
        print('❌ Windows: Failed to start playback: $e');
        throw Exception('Failed to start playback: $e');
      }

    } catch (e) {
      print('❌ Windows: Error playing radio station: $e');
      print('❌ Windows: Error type: ${e.runtimeType}');
      _currentStation = null;
      rethrow;
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentStation = null;
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  /// Check if running on Windows
  static bool get isWindows => Platform.isWindows;
}
