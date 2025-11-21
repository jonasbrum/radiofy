import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionService {
  /// Request all necessary permissions for audio playback and notifications
  static Future<bool> requestAllPermissions(BuildContext? context) async {
    print('🔔 Requesting all necessary permissions...');
    
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      print('📱 Notification permission: $notificationStatus');
      
      // Request audio permission
      final audioStatus = await Permission.audio.request();
      print('🎵 Audio permission: $audioStatus');
      
      // Request microphone permission (some devices require this for audio)
      final microphoneStatus = await Permission.microphone.request();
      print('🎤 Microphone permission: $microphoneStatus');
      
      // Request phone permission (for audio focus)
      final phoneStatus = await Permission.phone.request();
      print('📞 Phone permission: $phoneStatus');
      
      // Check if all critical permissions are granted
      final allGranted = notificationStatus.isGranted && audioStatus.isGranted;
      
      if (allGranted) {
        print('✅ All critical permissions granted');
        return true;
      } else {
        print('❌ Some permissions were denied');
        
        // Show info dialog about missing permissions
        if (context != null) {
          _showPermissionInfoDialog(context, notificationStatus, audioStatus);
        }
        
        return false;
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Check if notification permissions are granted
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    print('🔔 Notification permission status: $status');
    return status.isGranted;
  }
  
  /// Check if audio permissions are granted
  static Future<bool> hasAudioPermission() async {
    final status = await Permission.audio.status;
    print('🎵 Audio permission status: $status');
    return status.isGranted;
  }
  
  /// Request notification permission with user-friendly dialog
  static Future<bool> requestNotificationPermission(BuildContext? context) async {
    print('🔔 Requesting notification permission...');
    
    // Check current status
    final currentStatus = await Permission.notification.status;
    print('📱 Current notification permission: $currentStatus');
    
    if (currentStatus.isGranted) {
      print('✅ Notification permission already granted');
      return true;
    }
    
    // Show explanation dialog first
    if (context != null) {
      final shouldProceed = await _showPermissionExplanationDialog(context);
      if (!shouldProceed) {
        print('❌ User declined permission request');
        return false;
      }
    }
    
    // Request permission
    final status = await Permission.notification.request();
    print('📱 Notification permission result: $status');
    
    if (status.isGranted) {
      print('✅ Notification permission granted');
      return true;
    } else if (status.isPermanentlyDenied) {
      print('❌ Notification permission permanently denied');
      if (context != null) {
        _showSettingsDialog(context);
      }
      return false;
    } else {
      print('❌ Notification permission denied');
      return false;
    }
  }
  
  /// Show explanation dialog before requesting permission
  static Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('Enable Notifications'),
          ],
        ),
        content: const Text(
          'Radiofy needs notification permission to:\n\n'
          '• Show playback controls when app is minimized\n'
          '• Display current station information\n'
          '• Allow you to control playback from notification bar\n\n'
          'This permission is essential for background audio playback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Show info dialog about permission status
  static void _showPermissionInfoDialog(BuildContext context, 
      PermissionStatus notificationStatus, PermissionStatus audioStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Permission Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification: ${_getPermissionStatusText(notificationStatus)}'),
            Text('Audio: ${_getPermissionStatusText(audioStatus)}'),
            const SizedBox(height: 16),
            const Text('Some features may not work properly without these permissions.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (notificationStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
  
  /// Show dialog to open app settings
  static void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'Notification permission is required for background playback.\n\n'
          'Please go to Settings > Apps > Radiofy > Permissions and enable Notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Get human-readable permission status text
  static String _getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted ✅';
      case PermissionStatus.denied:
        return 'Denied ❌';
      case PermissionStatus.restricted:
        return 'Restricted ⚠️';
      case PermissionStatus.limited:
        return 'Limited ⚠️';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied ❌';
      case PermissionStatus.provisional:
        return 'Provisional ⚠️';
    }
  }
  
  /// Check if we should show permission prompt
  static Future<bool> shouldShowPermissionPrompt() async {
    final status = await Permission.notification.status;
    return !status.isGranted;
  }
}