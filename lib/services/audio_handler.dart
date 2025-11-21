import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import 'scraping_service.dart';

class RadioAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  RadioStation? _currentStation;

  RadioAudioHandler() {
    print('🎵 Initializing RadioAudioHandler...');
    _initializeAudioPlayer();
    _initializePlaybackState();
    print('✅ RadioAudioHandler initialized');
  }

  void _initializePlaybackState() {
    print('🔧 Initializing playback state...');
    playbackState.add(PlaybackState(
      controls: [MediaControl.play],
      systemActions: const {MediaAction.play},
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
    print('✅ Initial playback state set');
  }

  void _initializeAudioPlayer() {
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      
      print('🎵 AudioPlayer state: playing=$isPlaying, processing=$processingState');

      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        print('📻 Setting AudioService state: LOADING');
        playbackState.add(playbackState.value.copyWith(
          controls: [MediaControl.stop],
          systemActions: const {
            MediaAction.stop,
          },
          processingState: AudioProcessingState.loading,
          playing: true, // Keep playing=true to indicate we're attempting to play
        ));
      } else if (processingState == ProcessingState.completed) {
        print('📻 Setting AudioService state: COMPLETED');
        playbackState.add(playbackState.value.copyWith(
          controls: [MediaControl.play],
          systemActions: const {
            MediaAction.play,
          },
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
      } else {
        print('📻 Setting AudioService state: playing=$isPlaying');
        playbackState.add(playbackState.value.copyWith(
          controls: isPlaying
              ? [MediaControl.stop, MediaControl.pause]
              : [MediaControl.play],
          systemActions: isPlaying
              ? {MediaAction.stop, MediaAction.pause}
              : {MediaAction.play},
          processingState: isPlaying
              ? AudioProcessingState.ready
              : AudioProcessingState.ready,
          playing: isPlaying,
        ));
      }
    });
  }

  Future<void> playRadioStation(RadioStation station) async {
    try {
      _currentStation = station;
      
      print('📻 Setting up media item for ${station.name}');

      // Create media item with proper metadata
      final mediaItemToSet = MediaItem(
        id: station.url,
        album: '${station.city}, ${station.country}',
        title: station.name,
        artist: 'FM ${station.frequency}',
        duration: null, // Live stream
        artUri: station.logoUrl != null ? Uri.parse(station.logoUrl!) : null,
        playable: true,
        extras: {
          'isLiveStream': true,
          'country': station.country,
          'city': station.city,
          'frequency': station.frequency,
        },
      );
      
      print('📻 Setting media item: ${mediaItemToSet.title}');
      mediaItem.add(mediaItemToSet);

      // Let the automatic state management handle the notification display

      String actualStreamUrl = station.url;

      // If the URL is a play page, resolve it to actual streaming URL
      if (station.url.contains('/play/') && !station.url.contains('.m3u') && !station.url.contains('.pls')) {
        print('🔍 Resolving streaming URL from play page...');
        final resolvedUrl = await ScrapingService.getStreamUrlFromPlayPage(station.url);
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          actualStreamUrl = resolvedUrl;
          print('✅ Resolved streaming URL: $actualStreamUrl');
        } else {
          throw Exception('Could not resolve streaming URL for ${station.name}');
        }
      }

      print('📻 Starting playback of $actualStreamUrl');
      await _audioPlayer.setUrl(actualStreamUrl);
      await _audioPlayer.play();
      
      print('✅ Playback started successfully - letting audio player stream manage state');
    } catch (e) {
      print('❌ Playback failed: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
      
      final errorMessage = e.toString();
      if (errorMessage.contains('(0)') || errorMessage.toLowerCase().contains('source error')) {
        throw Exception('Radio is Offline, try again later');
      }
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    print('▶️ Play button pressed');
    if (_currentStation != null) {
      print('▶️ Resuming current station: ${_currentStation!.name}');
      await _audioPlayer.play();
      // Let the automatic stream listener handle state updates
    } else {
      print('▶️ No current station to resume');
      await _audioPlayer.play();
    }
  }

  @override
  Future<void> pause() async {
    print('⏸ Pausing playback...');
    await _audioPlayer.pause();
    // Let the automatic stream listener handle state updates
  }

  @override
  Future<void> stop() async {
    print('⏹️ Stopping playback...');
    await _audioPlayer.stop();
    _currentStation = null;
    
    // Force stop state immediately
    playbackState.add(PlaybackState(
      controls: [MediaControl.play],
      systemActions: const {MediaAction.play},
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
    
    // Clear the media item to hide notification
    mediaItem.add(null);
    print('✅ Playback stopped and notification cleared');
  }

  @override
  Future<void> seek(Duration position) async {
    // Radio streams don't support seeking
  }

  RadioStation? get currentStation => _currentStation;
  AudioPlayer get audioPlayer => _audioPlayer;

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
  }

  /// Force display notification for testing
  Future<void> forceShowNotification() async {
    print('📢 FORCING notification display...');
    
    // Set a test media item
    final testMediaItem = MediaItem(
      id: 'test',
      title: 'Radiofy Test',
      artist: 'Testing Notification',
      album: 'Test Album',
      duration: null,
    );
    
    mediaItem.add(testMediaItem);
    
    // Force playing state
    playbackState.add(PlaybackState(
      controls: [MediaControl.stop, MediaControl.pause, MediaControl.play],
      systemActions: const {MediaAction.stop, MediaAction.pause, MediaAction.play},
      processingState: AudioProcessingState.ready,
      playing: true,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
    
    print('✅ Test notification should now be visible');
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}