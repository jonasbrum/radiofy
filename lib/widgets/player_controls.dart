import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/app_state.dart';
import '../models/radio_station.dart';
import '../services/windows_audio_service.dart';

class PlayerControls extends StatelessWidget {
  final AppState appState;

  // Non-const to ensure rebuilds aren't blocked
  PlayerControls({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    print('🎛️ PlayerControls building...');
    print('🔄🔄🔄 PlayerControls REBUILD! AppState: ${appState.hashCode}');
    print('🔄 currentStation: ${appState.currentStation?.name}, isPlaying: ${appState.isPlaying}, isLoading: ${appState.isLoading}');

    final station = appState.currentStation;
    if (station == null) {
      print('🎛️ Station is null - returning empty widget');
      return const SizedBox.shrink();
    }

    // Use AppState which properly handles AudioService + fallback
    final isPlaying = appState.isPlaying;
    final isLoading = appState.isLoading;

    return _buildControlBar(context, station, isPlaying, isLoading);
  }

  Widget _buildControlBar(BuildContext context, station, bool isPlaying, bool isLoading) {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a1a),
            border: Border(
              top: BorderSide(
                color: Color(0xFF2a2a2a),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Station logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                    ),
                  ),
                  child: station.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            station.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.radio,
                                color: Color(0xFFFF6B35),
                                size: 24,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.radio,
                          color: Color(0xFFFF6B35),
                          size: 24,
                        ),
                ),
                const SizedBox(width: 16),
                
                // Station info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isPlaying)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B35),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            isPlaying 
                                ? 'Now Playing'
                                : isLoading
                                    ? 'Loading...'
                                    : 'Stopped',
                            style: TextStyle(
                              color: isPlaying 
                                  ? const Color(0xFFFF6B35)
                                  : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          if (station.frequency.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            Text(
                              station.frequency,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Volume control (Windows only)
                if (Platform.isWindows) ...[
                  const SizedBox(width: 16),
                  const _VolumeSlider(),
                ],

                const SizedBox(width: 16),

                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Favorite button
                    FutureBuilder<bool>(
                      future: Provider.of<AppState>(context, listen: false).isFavorite(station),
                      builder: (context, snapshot) {
                        final isFavorite = snapshot.data ?? false;
                        return IconButton(
                          onPressed: () => Provider.of<AppState>(context, listen: false).toggleFavorite(station),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite 
                                ? const Color(0xFFFF6B35) 
                                : Colors.grey,
                            size: 24,
                          ),
                        );
                      },
                    ),
                    
                    // Play/Pause button
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () async {
                          // Use AppState methods to ensure proper UI synchronization
                          try {
                            final appState = Provider.of<AppState>(context, listen: false);
                            print('🎵 Control bar: isPlaying=$isPlaying, currentStation=${appState.currentStation?.name}');
                            if (isPlaying) {
                              print('🎵 Control bar: Calling appState.pausePlayback()');
                              await appState.pausePlayback();
                            } else {
                              print('🎵 Control bar: Calling appState.resumePlayback()');
                              await appState.resumePlayback();
                            }
                          } catch (e) {
                            print('❌ Control bar play/pause failed: $e');
                          }
                        },
                        icon: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                isPlaying 
                                    ? Icons.pause 
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                    
                    // Stop button - copy exact behavior from notification controls
                    IconButton(
                      onPressed: () async {
                        // Use AppState method to ensure proper UI synchronization
                        try {
                          final appState = Provider.of<AppState>(context, listen: false);
                          print('🎵 Control bar: Calling appState.stopPlayback() for ${appState.currentStation?.name}');
                          await appState.stopPlayback();
                        } catch (e) {
                          print('❌ Control bar stop failed: $e');
                        }
                      },
                      icon: const Icon(
                        Icons.stop,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}

// Volume slider widget for Windows
class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider();

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double _volume = 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _volume == 0 ? Icons.volume_off : Icons.volume_up,
          color: Colors.grey,
          size: 20,
        ),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFFFF6B35),
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
              thumbColor: const Color(0xFFFF6B35),
              overlayColor: const Color(0xFFFF6B35).withOpacity(0.2),
            ),
            child: Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) async {
                setState(() {
                  _volume = value;
                });
                if (Platform.isWindows) {
                  await WindowsAudioService().setVolume(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}