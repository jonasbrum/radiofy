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
      _currentStation = station;

      String? streamUrl = station.streamUrl;

      // If no stream URL, try to scrape it
      if (streamUrl == null || streamUrl.isEmpty) {
        print('🔍 Windows: No stream URL, attempting to scrape...');
        try {
          streamUrl = await ScrapingService.getStreamUrl(station.url);
          if (streamUrl == null || streamUrl.isEmpty) {
            throw Exception('Could not find stream URL');
          }
          print('✅ Windows: Found stream URL: $streamUrl');
        } catch (e) {
          print('❌ Windows: Failed to scrape stream URL: $e');
          throw Exception('Failed to get stream URL: $e');
        }
      }

      print('🎵 Windows: Setting audio source: $streamUrl');
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(streamUrl)),
      );

      print('▶️  Windows: Starting playback...');
      await _audioPlayer.play();
      print('✅ Windows: Playback started');

    } catch (e) {
      print('❌ Windows: Error playing radio station: $e');
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
