import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/app_state.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'services/simple_audio_handler.dart';
import 'services/notification_permission_service.dart';
import 'screens/setup_screen.dart';
import 'screens/main_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

RadioAudioHandler? _audioHandler;
bool _isInitializing = false;
bool _isInitialized = false;
bool _hasBeenInitialized = false; // Track if AudioService.init was ever called
String? _lastInitializationError; // Store last error for UI display

RadioAudioHandler? get audioHandler => _audioHandler;
String? get lastInitializationError => _lastInitializationError;

/// Reset audio service state for debugging (but can't reset the actual AudioService)
void resetAudioServiceState() {
  print('🔄 Resetting audio service state...');
  print('⚠️  Note: AudioService.init() can only be called once per app session');
  _audioHandler = null;
  _isInitialized = false;
  _isInitializing = false;
  // Don't reset _hasBeenInitialized - that's permanent
  print('✅ Local audio service state reset');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage service
  await StorageService.init();
  
  // Don't initialize AudioService in background - will be done on first use
  print('🔧 AudioService will be initialized on first use');
  // _initializeAudioServiceInBackground();
  
  runApp(const MyApp());
}

void _initializeAudioServiceInBackground() {
  // Initialize audio service without blocking the main thread
  print('⏰ Scheduling background audio service initialization in 3 seconds...');
  Future.delayed(const Duration(seconds: 3), () async {
    try {
      print('🔧 Starting background audio service initialization...');
      print('🔍 Current handler before init: $_audioHandler');
      print('🔍 Is initialized: $_isInitialized');
      print('🔍 Is initializing: $_isInitializing');
      
      await initializeAudioService();
      
      print('✅ Background audio service initialization completed');
      print('🔍 Current handler after init: $_audioHandler');
      print('🔍 Is initialized: $_isInitialized');
    } catch (e) {
      print('❌ Failed to initialize audio service in background: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  });
}

Future<void> initializeAudioService() async {
  if (_isInitialized && _audioHandler != null) {
    print('✅ Audio service already initialized');
    return;
  }
  
  if (_isInitializing) {
    print('⏳ Audio service initialization already in progress');
    return;
  }
  
  if (_hasBeenInitialized) {
    print('❌ AudioService.init() has already been called in this app session');
    print('❌ Cannot reinitialize AudioService - this is a limitation of the audio_service package');
    return;
  }
  
  _isInitializing = true;
  
  try {
    print('🔧 Starting audio service initialization...');
    _lastInitializationError = null; // Clear previous error
    
    print('🔧 Creating RadioAudioHandler...');
    
    // Test if we can create the handler first
    print('🧪 Back to RadioAudioHandler...');
    RadioAudioHandler handler;
    try {
      handler = RadioAudioHandler();
      print('✅ RadioAudioHandler created successfully');
    } catch (e) {
      _lastInitializationError = 'Failed to create RadioAudioHandler: $e';
      throw Exception('Failed to create RadioAudioHandler: $e');
    }
    
    print('🔧 Calling AudioService.init...');
    try {
      _audioHandler = await AudioService.init(
        builder: () => handler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.radiofy.app.channel.audio',
          androidNotificationChannelName: 'Radiofy Player',
          androidNotificationChannelDescription: 'Radio streaming controls',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidStopForegroundOnPause: true,
          androidResumeOnClick: true,
          androidNotificationOngoing: true,
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _lastInitializationError = 'AudioService.init() timed out after 30 seconds';
          throw Exception('AudioService.init() timed out after 30 seconds');
        },
      );
    } catch (e) {
      _lastInitializationError = 'AudioService.init() failed: $e';
      throw Exception('AudioService.init() failed: $e');
    }
    
    _isInitialized = true;
    _hasBeenInitialized = true; // Mark as permanently initialized
    print('✅ AudioService.init completed successfully!');
    print('✅ AudioHandler is available: ${_audioHandler != null}');
    print('✅ AudioHandler type: ${_audioHandler.runtimeType}');
    
    // Test basic functionality
    if (_audioHandler != null) {
      print('🧪 Testing audio handler functionality...');
      try {
        await _audioHandler!.forceShowNotification();
        print('✅ Test notification sent successfully');
      } catch (e) {
        print('❌ Test notification failed: $e');
      }
    }
    
  } catch (e) {
    final errorMessage = 'Failed to initialize audio service: $e';
    final errorType = 'Error type: ${e.runtimeType}';
    print('❌ $errorMessage');
    print('❌ $errorType');
    print('❌ Stack trace: ${StackTrace.current}');
    
    // Store error for UI display
    _lastInitializationError = '$errorMessage\n$errorType';
    
    _audioHandler = null;
    _isInitialized = false;
    _hasBeenInitialized = true; // Still mark as attempted, can't try again
    // Don't rethrow - let app continue without audio service
  } finally {
    _isInitializing = false;
  }
}

/// Ensure audio service is initialized and ready
Future<bool> ensureAudioServiceReady() async {
  if (_audioHandler == null) {
    print('🔧 Audio service not ready, initializing...');
    try {
      await initializeAudioService();
    } catch (e) {
      print('❌ Failed to initialize audio service: $e');
      return false;
    }
  }
  
  final isReady = _audioHandler != null;
  print('🎵 Audio service ready: $isReady');
  return isReady;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Radiofy',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF6B35), // Orange like logo
                brightness: appState.isDarkMode ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: appState.isDarkMode 
                  ? const Color(0xFF0d0d0d) 
                  : Colors.white,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // Give a brief moment to show the splash screen
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    // Request all necessary permissions
    print('🔔 Requesting all necessary permissions...');
    try {
      await NotificationPermissionService.requestAllPermissions(context);
    } catch (e) {
      print('❌ Permission request failed: $e');
    }
    
    try {
      final isFirstLaunch = await StorageService.isFirstLaunch();
      
      if (isFirstLaunch) {
        // First time opening the app
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SetupScreen(),
            ),
          );
        }
      } else {
        // App has been set up before
        // Load previous selections and go to main screen
        final country = await StorageService.getSelectedCountry();
        final city = await StorageService.getSelectedCity();
        
        if (!mounted) return;
        final appState = Provider.of<AppState>(context, listen: false);
        
        if (country != null && city != null) {
          appState.setSelectedCountry(country);
          appState.setSelectedCity(city);
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MainScreen(), // NO CONST!
              ),
            );
          }
        } else {
          // Somehow the stored data is incomplete, go to setup
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SetupScreen(),
              ),
            );
          }
        }
      }
    } catch (e) {
      // If there's an error, default to setup screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SetupScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d0d),
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/radiofyicon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // App name
              const Text(
                'Radiofy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              const Text(
                'World Radio at Your Fingertips',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 48),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}