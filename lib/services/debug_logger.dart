import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebugLogger {
  static File? _logFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (Platform.isWindows) {
        // Get user's documents folder
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}\\Radiofy');

        // Create directory if it doesn't exist
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        _logFile = File('${logDir.path}\\radiofy_debug.log');

        // Clear old log on startup
        if (await _logFile!.exists()) {
          await _logFile!.writeAsString('');
        }

        await log('=== Radiofy Debug Log Started ===');
        await log('Log file: ${_logFile!.path}');
        _initialized = true;
      }
    } catch (e) {
      print('Failed to initialize debug logger: $e');
    }
  }

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] $message';

    // Always print to console
    print(logMessage);

    // Also write to file on Windows
    if (Platform.isWindows && _logFile != null) {
      try {
        await _logFile!.writeAsString(
          '$logMessage\n',
          mode: FileMode.append,
        );
      } catch (e) {
        print('Failed to write to log file: $e');
      }
    }
  }

  static String? get logFilePath => _logFile?.path;
}
