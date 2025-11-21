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
      print('=== WINDOWS AUDIO DEBUG START ===');
      print('🎵 Station: ${station.name}');
      print('🎵 City: ${station.city}, ${station.country}');
      print('🎵 Original URL: ${station.url}');
      print('🎵 URL contains /play/: ${station.url.contains('/play/')}');
      print('🎵 URL contains .m3u: ${station.url.contains('.m3u')}');
      print('🎵 URL contains .pls: ${station.url.contains('.pls')}');

      _currentStation = station;

      String actualStreamUrl = station.url;

      // If the URL is a play page, resolve it to actual streaming URL
      if (station.url.contains('/play/') && !station.url.contains('.m3u') && !station.url.contains('.pls')) {
        print('🔍 Windows: URL needs resolution, calling getStreamUrlFromPlayPage...');
        try {
          final resolvedUrl = await ScrapingService.getStreamUrlFromPlayPage(station.url)
              .timeout(const Duration(seconds: 15));
          print('🔍 Resolution result: $resolvedUrl');

          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            actualStreamUrl = resolvedUrl;
            print('✅ Resolved to: $actualStreamUrl');
          } else {
            print('❌ Resolution returned null or empty');
            throw Exception('Could not resolve streaming URL for ${station.name}');
          }
        } catch (e) {
          print('❌ Resolution error: $e');
          print('❌ Error stack: ${StackTrace.current}');
          throw Exception('Failed to get stream URL: $e');
        }
      } else {
        print('ℹ️  Using direct URL (no resolution needed)');
      }

      print('🎵 Final URL to play: $actualStreamUrl');
      print('🎵 Calling audioPlayer.setUrl()...');

      try {
        await _audioPlayer.setUrl(actualStreamUrl).timeout(const Duration(seconds: 20));
        print('✅ setUrl() completed successfully');
      } catch (e) {
        print('❌ setUrl() failed with error: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error details: ${e.toString()}');
        throw Exception('Failed to load audio stream: $e');
      }

      print('▶️  Calling audioPlayer.play()...');
      try {
        await _audioPlayer.play();
        print('✅ play() completed successfully');
        print('=== WINDOWS AUDIO DEBUG END ===');
      } catch (e) {
        print('❌ play() failed with error: $e');
        throw Exception('Failed to start playback: $e');
      }

    } catch (e) {
      print('❌ FINAL ERROR: $e');
      print('❌ Error type: ${e.runtimeType}');
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
