import 'package:flutter/material.dart';
import '../models/radio_station.dart';

class StationCard extends StatefulWidget {
  final RadioStation station;
  final bool isCurrentStation;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onToggleFavorite;

  const StationCard({
    super.key,
    required this.station,
    required this.isCurrentStation,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlay,
    required this.onStop,
    required this.onToggleFavorite,
  });

  @override
  State<StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<StationCard> {
  final bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    // This will be updated by the parent widget through provider
    // For now, we'll use a simple approach
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isCurrentStation 
            ? const Color(0xFF2a2a2a) 
            : const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: widget.isCurrentStation
            ? Border.all(color: const Color(0xFFFF6B35), width: 2)
            : Border.all(color: const Color(0xFF2a2a2a), width: 1),
        boxShadow: widget.isCurrentStation ? [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (widget.isCurrentStation && widget.isPlaying) {
              widget.onStop();
            } else {
              widget.onPlay();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: Logo and favorite button
                Row(
                  children: [
                    // Station logo
                    Expanded(
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                          ),
                        ),
                        child: widget.station.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.station.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.radio,
                                      color: Color(0xFFFF6B35),
                                      size: 32,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.radio,
                                color: Color(0xFFFF6B35),
                                size: 32,
                              ),
                      ),
                    ),
                    
                    // Favorite button
                    IconButton(
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite 
                            ? const Color(0xFFFF6B35) 
                            : Colors.grey,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Station name
                Text(
                  widget.station.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // Frequency
                Text(
                  widget.station.frequency,
                  style: TextStyle(
                    color: widget.isCurrentStation 
                        ? const Color(0xFFFF6B35) 
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Location
                Text(
                  '${widget.station.city}, ${widget.station.country}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const Spacer(),
                
                // Bottom section: Play button and status
                Row(
                  children: [
                    // Now playing indicator
                    if (widget.isCurrentStation && widget.isPlaying)
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B35),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Playing',
                                style: TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    
                    // Play/Stop button
                    Container(
                      decoration: BoxDecoration(
                        color: widget.isCurrentStation && widget.isPlaying
                            ? const Color(0xFFFF6B35)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6B35),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (widget.isCurrentStation && widget.isPlaying) {
                            widget.onStop();
                          } else {
                            widget.onPlay();
                          }
                        },
                        icon: widget.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                widget.isCurrentStation && widget.isPlaying
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                color: widget.isCurrentStation && widget.isPlaying
                                    ? Colors.white
                                    : const Color(0xFFFF6B35),
                                size: 18,
                              ),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}