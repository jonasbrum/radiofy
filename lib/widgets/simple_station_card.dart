import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_station.dart';
import '../providers/app_state.dart';

class SimpleStationCard extends StatelessWidget {
  final RadioStation station;
  final AppState appState;

  // Non-const to ensure rebuilds aren't blocked
  SimpleStationCard({
    super.key,
    required this.station,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    print('🔄🔄🔄 StationCard[${station.name}] REBUILD! AppState: ${appState.hashCode}');
    print('🔄 Current: ${appState.currentStation?.name}, isPlaying: ${appState.isPlaying}, isLoading: ${appState.isLoading}');

    final isCurrentStation = appState.currentStation?.url == station.url;

    // Use AppState which properly handles AudioService + fallback
    final isPlaying = appState.isPlaying;
    final isLoading = appState.isLoading;

    // Only show playing/loading state if this is the current station
    final showPlaying = isPlaying && isCurrentStation;
    final showLoading = isLoading && isCurrentStation;

    return _buildCard(context, appState, isCurrentStation, isPlaying, isLoading, showPlaying, showLoading);
  }

  Widget _buildCard(BuildContext context, AppState appState, bool isCurrentStation, bool isPlaying, bool isLoading, bool showPlaying, bool showLoading) {
    // Disable stations that are offline (checked in background)
    final isDisabled = !station.isOnline;
    
    return Card(
          elevation: isCurrentStation ? 6 : 2,
          color: isDisabled 
              ? const Color(0xFF0a0a0a) // Darker for disabled stations
              : isCurrentStation ? const Color(0xFF2a2a2a) : const Color(0xFF1a1a1a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCurrentStation ? const Color(0xFFFF6B35) : Colors.transparent,
              width: isCurrentStation ? 2 : 0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: null, // Disable card tap - only play button should work
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo area (bigger and transparent)
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // Main logo/icon
                        Center(
                          child: station.logoUrl != null && station.logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    station.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.radio,
                                        color: isDisabled ? Colors.grey.shade700 : Colors.grey,
                                        size: 48,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.radio,
                                  color: isDisabled ? Colors.grey.shade700 : Colors.grey,
                                  size: 48,
                                ),
                        ),
                        // Offline indicator
                        if (isDisabled)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.offline_bolt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Station name only
                  Expanded(
                    child: Text(
                      station.name,
                      style: TextStyle(
                        color: isDisabled ? Colors.grey.shade600 : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Bottom row: Status and play button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Playing indicator or favorite
                      if (showPlaying)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            // Use synchronous check with cached favorites list
                            final isFavorite = appState.isFavoriteSync(station);
                            return GestureDetector(
                              onTap: isDisabled ? null : () => appState.toggleFavorite(station),
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isDisabled
                                    ? Colors.grey.shade700
                                    : isFavorite ? const Color(0xFFFF6B35) : Colors.grey,
                                size: 16,
                              ),
                            );
                          },
                        ),
                      
                      // Play button
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: showPlaying
                              ? const Color(0xFFFF6B35)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDisabled 
                                ? Colors.grey.shade700 
                                : const Color(0xFFFF6B35),
                            width: 1.5,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: isDisabled ? null : () async {
                            if (isCurrentStation && isPlaying) {
                              // Use AppState method to ensure proper UI synchronization
                              try {
                                print('🎵 Station card button: Calling appState.stopPlayback() for ${station.name}');
                                await appState.stopPlayback();
                              } catch (e) {
                                print('❌ Station card button stop failed: $e');
                              }
                            } else if (isCurrentStation && !isPlaying) {
                              // Use AppState method to ensure proper UI synchronization
                              try {
                                print('🎵 Station card button: Calling appState.resumePlayback() for ${station.name}');
                                await appState.resumePlayback();
                              } catch (e) {
                                print('❌ Station card button play failed: $e');
                              }
                            } else {
                              // Switch to different station
                              print('🎯 STATION CARD: Calling playStation on appState instance: ${appState.hashCode}');
                              print('🎯 STATION CARD: Current appState.currentStation = ${appState.currentStation?.name}');
                              try {
                                await appState.playStation(station, context);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error playing ${station.name}: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: showLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  showPlaying ? Icons.stop : Icons.play_arrow,
                                  color: isDisabled 
                                      ? Colors.grey.shade700 
                                      : showPlaying ? Colors.white : const Color(0xFFFF6B35),
                                  size: 16,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }
}