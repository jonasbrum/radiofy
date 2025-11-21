import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import 'scraping_service.dart';
import 'debug_logger.dart';

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
      await DebugLogger.log('=== WINDOWS AUDIO DEBUG START ===');
      await DebugLogger.log('🎵 Station: ${station.name}');
      await DebugLogger.log('🎵 City: ${station.city}, ${station.country}');
      await DebugLogger.log('🎵 Original URL: ${station.url}');
      await DebugLogger.log('🎵 URL contains /play/: ${station.url.contains('/play/')}');
      await DebugLogger.log('🎵 URL contains .m3u: ${station.url.contains('.m3u')}');
      await DebugLogger.log('🎵 URL contains .pls: ${station.url.contains('.pls')}');

      _currentStation = station;

      String actualStreamUrl = station.url;

      // If the URL is a play page, resolve it to actual streaming URL
      if (station.url.contains('/play/') && !station.url.contains('.m3u') && !station.url.contains('.pls')) {
        await DebugLogger.log('🔍 Windows: URL needs resolution, calling getStreamUrlFromPlayPage...');
        try {
          final resolvedUrl = await ScrapingService.getStreamUrlFromPlayPage(station.url)
              .timeout(const Duration(seconds: 15));
          await DebugLogger.log('🔍 Resolution result: $resolvedUrl');

          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            actualStreamUrl = resolvedUrl;
            await DebugLogger.log('✅ Resolved to: $actualStreamUrl');
          } else {
            await DebugLogger.log('❌ Resolution returned null or empty');
            throw Exception('Could not resolve streaming URL for ${station.name}');
          }
        } catch (e) {
          await DebugLogger.log('❌ Resolution error: $e');
          await DebugLogger.log('❌ Error stack: ${StackTrace.current}');
          throw Exception('Failed to get stream URL: $e');
        }
      } else {
        await DebugLogger.log('ℹ️  Using direct URL (no resolution needed)');
      }

      await DebugLogger.log('🎵 Final URL to play: $actualStreamUrl');
      await DebugLogger.log('🎵 Calling audioPlayer.setUrl()...');

      try {
        await _audioPlayer.setUrl(actualStreamUrl).timeout(const Duration(seconds: 20));
        await DebugLogger.log('✅ setUrl() completed successfully');
      } catch (e) {
        await DebugLogger.log('❌ setUrl() failed with error: $e');
        await DebugLogger.log('❌ Error type: ${e.runtimeType}');
        await DebugLogger.log('❌ Error details: ${e.toString()}');
        throw Exception('Failed to load audio stream: $e');
      }

      await DebugLogger.log('▶️  Calling audioPlayer.play()...');
      try {
        await _audioPlayer.play();
        await DebugLogger.log('✅ play() completed successfully');
        await DebugLogger.log('=== WINDOWS AUDIO DEBUG END ===');
      } catch (e) {
        await DebugLogger.log('❌ play() failed with error: $e');
        throw Exception('Failed to start playback: $e');
      }

    } catch (e) {
      await DebugLogger.log('❌ FINAL ERROR: $e');
      await DebugLogger.log('❌ Error type: ${e.runtimeType}');
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
