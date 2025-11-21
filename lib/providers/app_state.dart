import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/radio_station.dart';
import '../services/storage_service.dart';
import '../services/scraping_service.dart';
import '../services/windows_audio_service.dart';
import '../services/notification_permission_service.dart';
import '../main.dart';

class AppState extends ChangeNotifier {
  // Selected location
  Country? _selectedCountry;
  City? _selectedCity;

  // Radio stations
  List<RadioStation> _allStations = [];
  List<RadioStation> _favoriteStations = [];
  List<RadioStation> _lastPlayedStations = [];
  List<RadioStation> _searchResults = [];

  // Audio player - now using background service
  RadioStation? _currentStation;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _audioServiceListenersConnected = false;

  // Stream subscriptions for proper cleanup
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlayerState>? _fallbackPlayerSubscription;
  Timer? _audioServiceConnectionTimer;

  // Fallback audio player
  final AudioPlayer _fallbackPlayer = AudioPlayer();

  // Search
  String _searchQuery = '';

  // Theme
  bool _isDarkMode = true;

  // Getters
  Country? get selectedCountry => _selectedCountry;
  City? get selectedCity => _selectedCity;
  List<RadioStation> get allStations => _allStations;
  List<RadioStation> get favoriteStations => _favoriteStations;
  List<RadioStation> get lastPlayedStations => _lastPlayedStations;
  List<RadioStation> get searchResults => _searchResults;
  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  bool get isDarkMode => _isDarkMode;

  AppState() {
    print('🏗️🏗️🏗️ NEW AppState instance created! hashCode: ${this.hashCode}');
    _initializeAudioPlayer();
    _loadSettings();
    _setupAudioServiceConnection();
  }

  @override
  void notifyListeners() {
    print('📢📢📢 notifyListeners() CALLED! AppState: ${this.hashCode}');
    print('📢 State: currentStation=${_currentStation?.name}, isPlaying=$_isPlaying, isLoading=$_isLoading');
    super.notifyListeners();
  }

  void _initializeAudioPlayer() {
    // On Windows, use WindowsAudioService
    if (Platform.isWindows) {
      print('🪟 Setting up Windows audio service listeners');
      final windowsAudio = WindowsAudioService();
      _fallbackPlayerSubscription = windowsAudio.playerStateStream.listen((playerState) {
        print('🪟 Windows audio state: playing=${playerState.playing}, processing=${playerState.processingState}');

        final isLoadingOrBuffering = playerState.processingState == ProcessingState.loading ||
                                    playerState.processingState == ProcessingState.buffering;

        _isLoading = isLoadingOrBuffering;

        // Update playing state based on processing state
        if (playerState.processingState == ProcessingState.ready) {
          _isPlaying = playerState.playing;
        } else if (isLoadingOrBuffering) {
          _isPlaying = false; // Show as not playing but loading
        } else {
          _isPlaying = playerState.playing;
        }

        notifyListeners();
      });
      return;
    }

    // Setup fallback player for mobile platforms
    _fallbackPlayerSubscription = _fallbackPlayer.playerStateStream.listen((playerState) {
      // Only use fallback player state if AudioService is completely unavailable
      if (audioHandler == null) {
        print('🔙 Using fallback player state: playing=${playerState.playing}, processing=${playerState.processingState}');

        final isLoadingOrBuffering = playerState.processingState == ProcessingState.loading ||
                                    playerState.processingState == ProcessingState.buffering;

        _isLoading = isLoadingOrBuffering;

        // Update playing state based on processing state
        if (playerState.processingState == ProcessingState.ready) {
          _isPlaying = playerState.playing;
        } else if (isLoadingOrBuffering) {
          _isPlaying = false; // Show as not playing but loading
        } else {
          _isPlaying = playerState.playing;
        }

        notifyListeners();
      }
    });

    // AudioService connection will be handled by _setupAudioServiceListener()
  }

  // Set up periodic check for AudioService availability
  void _setupAudioServiceConnection() {
    // Try to connect immediately first
    if (!_audioServiceListenersConnected && audioHandler != null) {
      print('🔧 AudioService detected immediately, connecting listeners...');
      connectToAudioService();
      return;
    }

    // Then check every 500ms for AudioService availability (faster polling)
    // Store the timer so we can cancel it properly
    _audioServiceConnectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_audioServiceListenersConnected && audioHandler != null) {
        print('🔧 AudioService detected, connecting listeners...');
        connectToAudioService();
        timer.cancel();
        _audioServiceConnectionTimer = null;
      }
    });
  }

  // Connect to AudioService streams when it becomes available
  void connectToAudioService() {
    if (_audioServiceListenersConnected) {
      print('✅ AudioService listeners already connected, skipping');
      return;
    }

    if (audioHandler == null) {
      print('❌ Cannot connect to AudioService - handler is null');
      return;
    }

    try {
      print('🔧 Connecting to AudioService streams...');

      // Listen to audio service playback state - store subscription for cleanup
      _playbackStateSubscription = audioHandler!.playbackState.listen((playbackState) {
        print('📻 Playback state received: playing=${playbackState.playing}, processing=${playbackState.processingState}');
        print('📻 Current UI state: playing=$_isPlaying, loading=$_isLoading, currentStation=${_currentStation?.name}');

        final wasPlaying = _isPlaying;
        final wasLoading = _isLoading;

        // Handle different processing states
        final isLoadingOrBuffering = playbackState.processingState == AudioProcessingState.loading ||
                                    playbackState.processingState == AudioProcessingState.buffering;

        // Update loading state
        _isLoading = isLoadingOrBuffering;

        // Update playing state based on AudioService state
        if (playbackState.processingState == AudioProcessingState.ready) {
          // Ready state - use actual playing status
          _isPlaying = playbackState.playing;
        } else if (isLoadingOrBuffering) {
          // Loading/buffering - show as not playing but loading
          _isPlaying = false;
        } else if (playbackState.processingState == AudioProcessingState.idle) {
          // Idle state - not playing
          _isPlaying = false;
        } else {
          // Other states - use actual playing status
          _isPlaying = playbackState.playing;
        }

        print('🔄 New UI state: playing=$_isPlaying, loading=$_isLoading');

        // Always notify to ensure UI updates
        notifyListeners();

        if (wasPlaying != _isPlaying || wasLoading != _isLoading) {
          print('✅ State change detected and UI notified');
        } else {
          print('🔁 State unchanged but UI notified anyway');
        }
      });

      // CRITICAL FIX: Immediately read current playback state
      // Stream subscriptions only receive FUTURE emissions, not the current value
      // But BehaviorSubject has a .value property we can read synchronously
      print('🔍 Reading current playback state immediately...');
      final currentState = audioHandler!.playbackState.value;
      print('🔍 Current state: playing=${currentState.playing}, processing=${currentState.processingState}');

      // Update UI with current state immediately
      final isLoadingOrBuffering = currentState.processingState == AudioProcessingState.loading ||
                                  currentState.processingState == AudioProcessingState.buffering;
      _isLoading = isLoadingOrBuffering;

      if (currentState.processingState == AudioProcessingState.ready) {
        _isPlaying = currentState.playing;
      } else if (isLoadingOrBuffering) {
        _isPlaying = false;
      } else if (currentState.processingState == AudioProcessingState.idle) {
        _isPlaying = false;
      } else {
        _isPlaying = currentState.playing;
      }

      print('🔍 Initial UI state set: playing=$_isPlaying, loading=$_isLoading');
      notifyListeners(); // Update UI with current state immediately

      // Listen to media item changes - store subscription for cleanup
      _mediaItemSubscription = audioHandler!.mediaItem.listen((mediaItem) {
        if (mediaItem != null) {
          print('📻 Media item set: ${mediaItem.title}');
          // Don't override current station if we already have one playing
        } else {
          print('📻 Media item cleared - keeping current station during playback');
          // Don't clear current station during media item changes
          // Only clear it when explicitly stopping
        }
      });

      _audioServiceListenersConnected = true;
      print('✅ Audio service listeners connected successfully');

    } catch (e) {
      print('❌ Failed to connect to AudioService: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadSettings() async {
    _isDarkMode = await StorageService.isDarkMode();
    _selectedCountry = await StorageService.getSelectedCountry();
    _selectedCity = await StorageService.getSelectedCity();
    _favoriteStations = await StorageService.getFavoriteStations();
    _lastPlayedStations = await StorageService.getLastPlayedStations();
    notifyListeners();
  }

  // Location setters
  void setSelectedCountry(Country country) {
    _selectedCountry = country;
    notifyListeners();
  }

  void setSelectedCity(City city) {
    _selectedCity = city;
    notifyListeners();
  }

  // Load stations for selected city with progressive batch loading
  Future<void> loadStationsForCity() async {
    if (_selectedCity == null || _selectedCountry == null) return;

    try {
      // Clear existing stations first
      _allStations = [];
      notifyListeners();

      // Fetch all stations (this is fast - just HTML parsing)
      final stations = await ScrapingService.getStationsForCity(
        _selectedCity!,
        _selectedCountry!.name,
      );

      print('📡 Got ${stations.length} stations, showing immediately without validation...');

      // Show ALL stations immediately without validation
      // Mark them all as valid by default (lenient approach)
      _allStations = stations.map((s) => RadioStation(
        name: s.name,
        url: s.url,
        city: s.city,
        country: s.country,
        frequency: s.frequency,
        logoUrl: s.logoUrl,
        isValid: true,  // Assume valid - let playback determine if it works
        isOnline: true, // Assume online - let playback determine if it works
      )).toList();

      notifyListeners(); // Show all stations immediately!

      print('✅ Showing ${_allStations.length} stations immediately (validation skipped)');

      // Optional: Validate in background (don't await, don't block UI)
      // This updates stations as they're validated but doesn't prevent showing them
      _validateStationsInBackground(stations);

    } catch (e) {
      debugPrint('Error loading stations: $e');
    }
  }

  // Validate stations in background without blocking UI
  void _validateStationsInBackground(List<RadioStation> stations) async {
    print('🔄 Starting background validation...');
    const int batchSize = 10;

    for (int i = 0; i < stations.length; i += batchSize) {
      final batch = stations.skip(i).take(batchSize).toList();

      try {
        // Validate this batch
        final validatedBatch = await ScrapingService.validateStations(batch);

        // Update the corresponding stations in _allStations
        for (var validated in validatedBatch) {
          final index = _allStations.indexWhere((s) =>
            s.name == validated.name && s.frequency == validated.frequency
          );
          if (index != -1) {
            _allStations[index] = validated;
          }
        }

        // Call notifyListeners() to update UI with offline status
        notifyListeners();
        print('🔄 Validated ${i + batch.length}/${stations.length} stations in background');
      } catch (e) {
        print('⚠️ Background validation error: $e');
      }
    }

    print('✅ Background validation complete');
  }

  // Load stations in batches (background scraping)
  Future<void> loadStationsBatch(int batchSize) async {
    if (_selectedCountry == null) return;

    try {
      final cities = await ScrapingService.getCitiesForCountry(_selectedCountry!.code);
      
      for (int i = 0; i < cities.length && i < batchSize; i++) {
        final city = cities[i];
        final stations = await ScrapingService.getStationsForCity(
          city,
          _selectedCountry!.name,
        );
        _allStations.addAll(stations);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stations batch: $e');
    }
  }

  // Audio controls
  Future<void> playStation(RadioStation station, [BuildContext? context]) async {
    try {
      print('🎬 playStation() called for: ${station.name}');
      print('🎬 THIS AppState instance hashCode: ${this.hashCode}');
      print('🎬 Before: currentStation = ${_currentStation?.name}, isPlaying = $_isPlaying, isLoading = $_isLoading');

      // Set UI state FIRST before doing anything else
      // This ensures control bar appears immediately
      _currentStation = station;
      _isLoading = true;
      _isPlaying = false;

      print('🎬 After setting: currentStation = ${_currentStation?.name}, isPlaying = $_isPlaying, isLoading = $_isLoading');
      print('🎬 Calling notifyListeners() NOW...');

      notifyListeners(); // IMMEDIATE UI update - control bar appears now

      print('📻 notifyListeners() called - control bar SHOULD be visible now!');
      print('📻 Playing station: ${station.name} - ${station.url}');

      // Log validation status but allow playback attempt even if validation failed
      if (!station.isValid || !station.isOnline) {
        print('⚠️ Warning: Station validation failed (isValid=${station.isValid}, isOnline=${station.isOnline})');
        print('⚠️ Attempting to play anyway - station may still work...');
      }

      // Stop any currently playing station (wrapped in try-catch to not block)
      try {
        if (_isPlaying) {
          print('🔄 Stopping current playback before switching stations...');
          if (Platform.isWindows) {
            await WindowsAudioService().stop();
          } else if (audioHandler != null) {
            await AudioService.stop();
            await Future.delayed(const Duration(milliseconds: 100));
          } else {
            await _fallbackPlayer.stop();
          }
        }
      } catch (stopError) {
        print('⚠️ Error stopping previous playback (continuing anyway): $stopError');
      }
      
      if (station.url.isEmpty) {
        // Don't manually set _isLoading here - let AudioService handle it
        // Don't set _currentStation = null here to keep control bar visible
        notifyListeners();
        throw Exception('No streaming URL available for ${station.name}');
      }

      print('📻 Attempting to play ${station.name}');
      print('📻 Station URL: ${station.url}');

      // Windows: Use WindowsAudioService (skip AudioService entirely)
      if (Platform.isWindows) {
        print('🪟 Using Windows audio service');
        try {
          await WindowsAudioService().playRadioStation(station);
          print('✅ Station setup complete via Windows audio service');

          // Mark as playing immediately - the stream listener will update if it changes
          _isPlaying = true;
          _isLoading = false;
          notifyListeners();

          // Add to last played
          await StorageService.addLastPlayedStation(station);
          _lastPlayedStations = await StorageService.getLastPlayedStations();
          notifyListeners();

          print('✅ Windows playback initiated successfully');
          return; // Exit early for Windows
        } catch (e) {
          print('❌ Windows audio playback failed: $e');
          _isLoading = false;
          _isPlaying = false;
          notifyListeners();

          // Show user-friendly error
          if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
            throw Exception('Station is not responding. Please try another station.');
          } else if (e.toString().contains('Failed to load audio stream')) {
            throw Exception('Unable to connect to station. The stream may be offline.');
          }
          rethrow;
        }
      }

      // Mobile platforms: Check permissions and use AudioService
      final hasNotificationPermission = await NotificationPermissionService.hasNotificationPermission();
      final hasAudioPermission = await NotificationPermissionService.hasAudioPermission();

      if ((!hasNotificationPermission || !hasAudioPermission) && context != null) {
        print('🔔 Requesting missing permissions...');
        await NotificationPermissionService.requestAllPermissions(context);
      }

      // Ensure audio service is initialized
      print('🔧 Ensuring audio service is ready...');
      final isReady = await ensureAudioServiceReady();

      // Also ensure AudioService listeners are connected
      if (isReady && !_audioServiceListenersConnected) {
        print('🔧 Connecting AudioService listeners now...');
        connectToAudioService();
      }

      if (!isReady) {
        print('❌ Audio service FAILED to initialize, using fallback');
      } else {
        print('✅ Audio service ready for playback');
      }

      // Mobile: Use AudioService
      if (audioHandler != null) {
        print('📱 Using unified AudioService approach');

        try {
          // First, set up the station in the handler (this is necessary for media item setup)
          await audioHandler!.playRadioStation(station);
          print('✅ Station set up and playing via AudioService');

          // CRITICAL FIX: Manually sync state after playback starts
          // The stream listener might not fire immediately, so force a sync
          await Future.delayed(const Duration(milliseconds: 100));
          final currentState = audioHandler!.playbackState.value;
          _isPlaying = currentState.playing;
          _isLoading = currentState.processingState == AudioProcessingState.loading ||
                      currentState.processingState == AudioProcessingState.buffering;
          print('🔄 Manual state sync after playback: playing=$_isPlaying, loading=$_isLoading');
          notifyListeners(); // Force UI update
        } catch (e) {
          print('❌ AudioService playback failed: $e');
          print('🔙 Falling back to basic audio player');
          await _playStationFallback(station);
        }
      } else {
        print('🔙 Falling back to basic audio player (NO NOTIFICATION)');
        // Fallback to basic audio player if service not initialized
        await _playStationFallback(station);
      }

      // Add to last played
      await StorageService.addLastPlayedStation(station);
      _lastPlayedStations = await StorageService.getLastPlayedStations();
      
      // Note: Don't manually update loading/playing state here - 
      // let the AudioService stream listeners handle UI state updates
      notifyListeners();
    } catch (e) {
      // Provide immediate error feedback
      _isLoading = false;
      _isPlaying = false;
      // Don't set _currentStation = null here to keep control bar visible for retry
      notifyListeners();

      final errorMessage = e.toString();
      print('❌ Error playing station ${station.name}: $errorMessage');

      // Provide clearer error messages based on the actual error
      if (errorMessage.contains('(0)') || errorMessage.toLowerCase().contains('source error')) {
        throw Exception('Unable to connect to station. The stream may be temporarily offline.');
      } else if (errorMessage.contains('offline or invalid')) {
        // This shouldn't happen anymore, but handle it gracefully
        throw Exception('Station may be offline. Attempting to play anyway...');
      } else if (errorMessage.toLowerCase().contains('no streaming url')) {
        throw Exception('No streaming URL found for this station. Please try another station.');
      }

      // For other errors, provide a generic but helpful message
      debugPrint('Error playing station ${station.name}: $e');
      rethrow;
    }
  }

  Future<void> _playStationFallback(RadioStation station) async {
    try {
      String actualStreamUrl = station.url;

      // If the URL is a play page, resolve it to actual streaming URL
      if (station.url.contains('/play/') && !station.url.contains('.m3u') && !station.url.contains('.pls')) {
        print('🔍 Resolving play page to streaming URL: ${station.url}');
        final resolvedUrl = await ScrapingService.getStreamUrlFromPlayPage(station.url);
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          actualStreamUrl = resolvedUrl;
          print('✅ Resolved to streaming URL: $actualStreamUrl');
        } else {
          throw Exception('Radio is Offline, try again later');
        }
      }

      print('📻 Starting fallback playback: $actualStreamUrl');
      await _fallbackPlayer.stop();
      await _fallbackPlayer.setUrl(actualStreamUrl);
      await _fallbackPlayer.play();
      print('✅ Fallback playback started');
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('(0)') || errorMessage.toLowerCase().contains('source error')) {
        throw Exception('Radio is Offline, try again later');
      }
      rethrow;
    }
  }

  Future<void> stopPlayback() async {
    print('⏹️ stopPlayback() called');
    try {
      // Windows: Use WindowsAudioService
      if (Platform.isWindows) {
        print('🪟 Calling Windows audio stop');
        await WindowsAudioService().stop();
        _currentStation = null;
        _isPlaying = false;
        _isLoading = false;
        notifyListeners();
        print('✅ Windows audio stop completed');
        return;
      }

      // Ensure AudioService is ready before calling
      final isReady = await ensureAudioServiceReady();
      if (isReady && audioHandler != null) {
        print('⏹️ Calling audioHandler.stop() directly (same as play action)');
        // Provide immediate UI feedback
        _currentStation = null;
        _isPlaying = false;
        _isLoading = false;
        notifyListeners();
        await audioHandler!.stop();
        print('✅ audioHandler.stop() completed');
      } else {
        print('⏹️ AudioService not ready, using fallback player stop');
        await _fallbackPlayer.stop();
        _currentStation = null;
        _isPlaying = false;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('❌ stopPlayback() failed: $e');
      // Fallback to direct player control
      try {
        await _fallbackPlayer.stop();
        _currentStation = null;
        _isPlaying = false;
        _isLoading = false;
        notifyListeners();
      } catch (fallbackError) {
        print('❌ Fallback stop also failed: $fallbackError');
      }
    }
    print('⏹️ Playback stopped, current station cleared');
  }

  Future<void> pausePlayback() async {
    print('⏸️ pausePlayback() called');
    try {
      // Windows: Use WindowsAudioService
      if (Platform.isWindows) {
        print('🪟 Calling Windows audio pause');
        await WindowsAudioService().pause();
        _isPlaying = false;
        notifyListeners();
        print('✅ Windows audio pause completed');
        return;
      }

      // Ensure AudioService is ready before calling
      final isReady = await ensureAudioServiceReady();
      if (isReady && audioHandler != null) {
        print('⏸️ Calling audioHandler.pause() directly (same as play action)');
        // Provide immediate UI feedback
        _isPlaying = false;
        notifyListeners();
        await audioHandler!.pause();
        print('✅ audioHandler.pause() completed');
      } else {
        print('⏸️ AudioService not ready, using fallback player pause');
        await _fallbackPlayer.pause();
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      print('❌ pausePlayback() failed: $e');
      // Fallback to direct player control
      try {
        await _fallbackPlayer.pause();
        _isPlaying = false;
        notifyListeners();
      } catch (fallbackError) {
        print('❌ Fallback pause also failed: $fallbackError');
      }
    }
  }

  Future<void> resumePlayback() async {
    print('▶️ resumePlayback() called');
    try {
      // Windows: Use WindowsAudioService
      if (Platform.isWindows) {
        print('🪟 Calling Windows audio play');
        await WindowsAudioService().play();
        _isPlaying = true;
        notifyListeners();
        print('✅ Windows audio play completed');
        return;
      }

      // Ensure AudioService is ready before calling
      final isReady = await ensureAudioServiceReady();
      if (isReady && audioHandler != null) {
        print('▶️ Calling audioHandler.play() directly (same as pause action)');
        // Provide immediate UI feedback
        _isPlaying = true;
        notifyListeners();
        await audioHandler!.play();
        print('✅ audioHandler.play() completed');
      } else {
        print('▶️ AudioService not ready, using fallback player play');
        await _fallbackPlayer.play();
        _isPlaying = true;
        notifyListeners();
      }
    } catch (e) {
      print('❌ resumePlayback() failed: $e');
      // Fallback to direct player control
      try {
        await _fallbackPlayer.play();
        _isPlaying = true;
        notifyListeners();
      } catch (fallbackError) {
        print('❌ Fallback play also failed: $fallbackError');
      }
    }
  }

  // Favorites
  Future<void> toggleFavorite(RadioStation station) async {
    print('❤️ toggleFavorite() called for: ${station.name}');

    final isFavorite = await StorageService.isFavoriteStation(station);
    print('❤️ Is currently favorite: $isFavorite');

    if (isFavorite) {
      print('❤️ Removing from favorites...');
      await StorageService.removeFavoriteStation(station);
    } else {
      print('❤️ Adding to favorites...');
      await StorageService.addFavoriteStation(station);
    }

    _favoriteStations = await StorageService.getFavoriteStations();
    print('❤️ Total favorites now: ${_favoriteStations.length}');
    print('❤️ Calling notifyListeners()...');
    notifyListeners();
    print('❤️ toggleFavorite() complete!');
  }

  Future<bool> isFavorite(RadioStation station) async {
    return await StorageService.isFavoriteStation(station);
  }

  // Synchronous favorite check using cached data
  bool isFavoriteSync(RadioStation station) {
    return _favoriteStations.any((s) => s.url == station.url && s.name == station.name);
  }

  // Search
  void setSearchQuery(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = _allStations.where((station) {
        return station.name.toLowerCase().contains(query.toLowerCase()) ||
               station.city.toLowerCase().contains(query.toLowerCase()) ||
               station.frequency.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // Theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await StorageService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  // Clear current station (for stop button)
  void clearCurrentStation() {
    _currentStation = null;
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    // Cancel all subscriptions
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _fallbackPlayerSubscription?.cancel();
    _audioServiceConnectionTimer?.cancel();

    // Dispose audio player
    _fallbackPlayer.dispose();

    // Audio service will be disposed by the system
    super.dispose();
  }
}