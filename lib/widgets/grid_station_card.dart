import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_station.dart';
import '../providers/app_state.dart';

class GridStationCard extends StatelessWidget {
  final RadioStation station;

  const GridStationCard({
    super.key,
    required this.station,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isCurrentStation = appState.currentStation?.url == station.url;
        final isPlaying = appState.isPlaying && isCurrentStation;
        final isLoading = appState.isLoading && isCurrentStation;

        return Card(
          elevation: isCurrentStation ? 8 : 2,
          color: isCurrentStation ? const Color(0xFF2a2a2a) : const Color(0xFF1a1a1a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isCurrentStation ? const Color(0xFFFF6B35) : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isCurrentStation && isPlaying) {
                appState.stopPlayback();
              } else {
                appState.playStation(station);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo section
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                            ),
                          ),
                          child: station.logoUrl != null && station.logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    station.logoUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.radio,
                                        color: Color(0xFFFF6B35),
                                        size: 40,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.radio,
                                  color: Color(0xFFFF6B35),
                                  size: 40,
                                ),
                        ),
                      ),
                      
                      // Favorite button
                      FutureBuilder<bool>(
                        future: appState.isFavorite(station),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;
                          return IconButton(
                            onPressed: () => appState.toggleFavorite(station),
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? const Color(0xFFFF6B35) : Colors.grey,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Station name
                  Text(
                    station.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Frequency
                  Text(
                    station.frequency,
                    style: TextStyle(
                      color: isCurrentStation ? const Color(0xFFFF6B35) : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Location
                  Text(
                    '${station.city}, ${station.country}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const Spacer(),
                  
                  // Bottom section
                  Row(
                    children: [
                      // Playing indicator
                      if (isCurrentStation && isPlaying) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Now Playing',
                            style: TextStyle(
                              color: Color(0xFFFF6B35),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Spacer(),
                      ],
                      
                      // Play button
                      Container(
                        decoration: BoxDecoration(
                          color: isCurrentStation && isPlaying
                              ? const Color(0xFFFF6B35)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B35),
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (isCurrentStation && isPlaying) {
                              appState.stopPlayback();
                            } else {
                              appState.playStation(station);
                            }
                          },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isCurrentStation && isPlaying ? Icons.stop : Icons.play_arrow,
                                  color: isCurrentStation && isPlaying ? Colors.white : const Color(0xFFFF6B35),
                                  size: 24,
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
      },
    );
  }
}