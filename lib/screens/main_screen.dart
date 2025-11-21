import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/radio_station.dart';
import '../widgets/simple_station_card.dart';
import '../widgets/player_controls.dart';
import '../widgets/search_bar.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingStations = false;
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Manually subscribe to AppState changes
    _appState = Provider.of<AppState>(context, listen: false);
    _appState.addListener(_onAppStateChanged);
    _loadInitialStations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Unsubscribe from AppState
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // CRITICAL: Force rebuild when AppState changes
  void _onAppStateChanged() {
    if (mounted) {
      setState(() {
        // Force rebuild - this WILL trigger build() to run
      });
    }
  }

  Future<void> _loadInitialStations() async {
    // Don't use local loading state - AppState handles it
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      print('Loading stations for city: ${appState.selectedCity?.name}');

      // Start loading asynchronously - don't await
      // This allows UI to update as batches load
      appState.loadStationsForCity().then((_) {
        print('Loaded ${appState.allStations.length} stations');
        if (mounted) {
          setState(() {
            _isLoadingStations = false;
          });
        }
      }).catchError((e) {
        print('Error loading stations: $e');
        if (mounted) {
          setState(() {
            _isLoadingStations = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading stations: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      // Set loading immediately but don't block
      setState(() {
        _isLoadingStations = true;
      });
    } catch (e) {
      print('Error starting station load: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔄🔄🔄 MainScreen build() called! AppState hashCode: ${_appState.hashCode}');
    print('🔄 currentStation: ${_appState.currentStation?.name}, isPlaying: ${_appState.isPlaying}');

    return Scaffold(
          backgroundColor: const Color(0xFF0d0d0d),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1a1a1a),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: const DecorationImage(
                      image: AssetImage('assets/radiofylogo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Radiofy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF6B35),
              labelColor: const Color(0xFFFF6B35),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'All Stations'),
                Tab(text: 'Favorites'),
                Tab(text: 'Recent'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search bar - hide in landscape orientation
              if (MediaQuery.of(context).orientation == Orientation.portrait)
                const CustomSearchBar(),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // All Stations Tab
                    _buildStationsTab(
                      _appState.searchQuery.isNotEmpty
                          ? _appState.searchResults
                          : _appState.allStations,
                      'No stations found',
                      _appState,
                    ),

                    // Favorites Tab
                    _buildStationsTab(
                      _appState.favoriteStations,
                      'No favorite stations yet\nTap the heart icon to add favorites',
                      _appState,
                    ),

                    // Recent Tab
                    _buildStationsTab(
                      _appState.lastPlayedStations,
                      'No recently played stations',
                      _appState,
                    ),
                  ],
                ),
              ),
              
              // Player controls at bottom - receives appState directly
              PlayerControls(
                key: ValueKey('player-${_appState.currentStation?.url ?? 'none'}'),
                appState: _appState,
              ),
            ],
          ),
        );
  }

  Widget _buildStationsTab(List<RadioStation> stations, String emptyMessage, AppState appState) {
    // Show loading spinner only when there are no stations at all
    if (stations.isEmpty) {
      // If we're actively loading, show spinner
      if (_isLoadingStations) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading stations...',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        );
      }

      // No stations and not loading - show empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_appState.allStations.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialStations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                ),
                child: const Text(
                  'Retry Loading',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Stations exist - show them in a grid
    return RefreshIndicator(
      onRefresh: () async {
        await _loadInitialStations();
      },
      color: const Color(0xFFFF6B35),
      backgroundColor: const Color(0xFF2a2a2a),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine number of columns based on screen width
          int crossAxisCount;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 5; // 5 per line for very wide screens
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 4; // 4 per line for tablets in landscape
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3; // 3 per line for tablets in portrait
          } else {
            crossAxisCount = 2; // 2 per line for phones
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85, // Make cards slightly taller than wide
            ),
            // Add extra item for loading indicator at the bottom if still loading
            itemCount: stations.length + (_isLoadingStations ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator as last item if still loading more stations
              if (index == stations.length && _isLoadingStations) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loading more...',
                        style: TextStyle(
                          color: Colors.grey.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final station = stations[index];
              // Use ValueKey with station URL to ensure proper rebuilds
              // Pass appState from parent Consumer to avoid nested Consumer issues
              return SimpleStationCard(
                key: ValueKey(station.url),
                station: station,
                appState: appState,
              );
            },
          );
        },
      ),
    );
  }
}