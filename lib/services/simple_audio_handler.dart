import 'package:audio_service/audio_service.dart';

class SimpleAudioHandler extends BaseAudioHandler {
  SimpleAudioHandler() {
    print('🎵 SimpleAudioHandler created');
    
    // Initialize with basic playback state
    playbackState.add(PlaybackState(
      controls: [MediaControl.play, MediaControl.pause, MediaControl.stop],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> play() async {
    print('▶️ SimpleAudioHandler play called');
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    print('⏸️ SimpleAudioHandler pause called');
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    print('⏹️ SimpleAudioHandler stop called');
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
}