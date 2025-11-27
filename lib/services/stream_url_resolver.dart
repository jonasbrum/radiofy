import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to resolve various streaming URL formats to actual playable URLs
class StreamUrlResolver {

  /// Resolve a URL to a playable streaming URL
  /// Handles: PLS playlists, M3U playlists, YouTube streams, direct URLs
  static Future<String> resolveUrl(String url) async {
    print('🔍 Resolving URL: $url');

    // YouTube URLs
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      print('📺 Detected YouTube URL');
      return await _resolveYouTubeUrl(url);
    }

    // PLS playlist files
    if (url.endsWith('.pls') || url.contains('.pls?')) {
      print('📄 Detected PLS playlist');
      return await _resolvePlsPlaylist(url);
    }

    // M3U playlist files (but not M3U8 HLS streams)
    if ((url.endsWith('.m3u') || url.contains('.m3u?')) && !url.contains('.m3u8')) {
      print('📄 Detected M3U playlist');
      return await _resolveM3uPlaylist(url);
    }

    // M3U8 HLS streams - return as-is (just_audio supports them)
    if (url.contains('.m3u8')) {
      print('📺 Detected M3U8 HLS stream - returning as-is');
      return url;
    }

    // Direct streams - return as-is
    print('🎵 Direct stream URL - returning as-is');
    return url;
  }

  /// Parse PLS playlist format and extract the first stream URL
  /// PLS format:
  /// [playlist]
  /// File1=https://stream-url.com/stream
  /// Title1=Station Name
  /// Length1=-1
  /// NumberOfEntries=1
  static Future<String> _resolvePlsPlaylist(String plsUrl) async {
    try {
      print('📥 Fetching PLS playlist from: $plsUrl');

      final response = await http.get(
        Uri.parse(plsUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('⚠️ PLS fetch failed with status ${response.statusCode}');
        return plsUrl; // Return original URL as fallback
      }

      final content = response.body;
      print('📄 PLS content received (${content.length} bytes)');

      // Parse PLS format - look for File1=, File2=, etc.
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        // Match File1=, File2=, etc. (case-insensitive)
        if (RegExp(r'^File\d+=', caseSensitive: false).hasMatch(trimmed)) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            // Join all parts after the first '=' in case the URL contains '='
            final streamUrl = parts.sublist(1).join('=').trim();
            if (streamUrl.isNotEmpty && streamUrl.startsWith('http')) {
              print('✅ Extracted stream URL from PLS: $streamUrl');
              return streamUrl;
            }
          }
        }
      }

      print('⚠️ No valid stream URL found in PLS file');
      return plsUrl; // Return original URL as fallback

    } catch (e) {
      print('❌ Error resolving PLS playlist: $e');
      return plsUrl; // Return original URL as fallback
    }
  }

  /// Parse M3U playlist format and extract the first stream URL
  /// M3U format:
  /// #EXTM3U
  /// #EXTINF:-1,Station Name
  /// https://stream-url.com/stream
  static Future<String> _resolveM3uPlaylist(String m3uUrl) async {
    try {
      print('📥 Fetching M3U playlist from: $m3uUrl');

      final response = await http.get(
        Uri.parse(m3uUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('⚠️ M3U fetch failed with status ${response.statusCode}');
        return m3uUrl; // Return original URL as fallback
      }

      final content = response.body;
      print('📄 M3U content received (${content.length} bytes)');

      // Parse M3U format - find first HTTP(S) URL that's not a comment
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        // Skip comments and empty lines
        if (!trimmed.startsWith('#') && trimmed.isNotEmpty) {
          if (trimmed.startsWith('http')) {
            print('✅ Extracted stream URL from M3U: $trimmed');
            return trimmed;
          }
        }
      }

      print('⚠️ No valid stream URL found in M3U file');
      return m3uUrl; // Return original URL as fallback

    } catch (e) {
      print('❌ Error resolving M3U playlist: $e');
      return m3uUrl; // Return original URL as fallback
    }
  }

  /// Extract YouTube stream URL from YouTube page or embed
  /// NOTE: YouTube live stream extraction is complex and may require
  /// youtube_explode_dart package or similar
  static Future<String> _resolveYouTubeUrl(String youtubeUrl) async {
    try {
      print('📺 Attempting to resolve YouTube URL: $youtubeUrl');

      // Extract video ID from various YouTube URL formats
      String? videoId;

      // Standard watch URL: youtube.com/watch?v=VIDEO_ID
      if (youtubeUrl.contains('youtube.com/watch?v=')) {
        final uri = Uri.parse(youtubeUrl);
        videoId = uri.queryParameters['v'];
      }
      // Short URL: youtu.be/VIDEO_ID
      else if (youtubeUrl.contains('youtu.be/')) {
        videoId = youtubeUrl.split('youtu.be/')[1].split('?')[0].split('&')[0];
      }
      // Embed URL: youtube.com/embed/VIDEO_ID
      else if (youtubeUrl.contains('youtube.com/embed/')) {
        videoId = youtubeUrl.split('/embed/')[1].split('?')[0].split('&')[0];
      }
      // Channel live: youtube.com/channel/CHANNEL_ID/live
      else if (youtubeUrl.contains('/live')) {
        // For live streams, we need to fetch the page and extract the video ID
        print('📺 Detected YouTube live stream URL');
        return await _extractYouTubeLiveStreamUrl(youtubeUrl);
      }

      if (videoId != null && videoId.isNotEmpty) {
        print('🆔 Extracted YouTube video ID: $videoId');

        // Try to get stream URL using youtube-nocookie iframe approach
        // This is a fallback - ideally use youtube_explode_dart package
        final iframeUrl = 'https://www.youtube-nocookie.com/embed/$videoId';
        print('📺 YouTube iframe URL: $iframeUrl');

        // For now, return the embed URL as it might work with some players
        // TODO: Integrate youtube_explode_dart for proper stream extraction
        print('⚠️ YouTube stream extraction requires additional package');
        print('⚠️ Returning embed URL as fallback: $iframeUrl');

        // Note: The app may need to handle YouTube differently (web view, etc.)
        throw Exception(
          'YouTube streams not yet supported. '
          'Please try playing this station in your browser or YouTube app.'
        );
      }

      print('⚠️ Could not extract video ID from YouTube URL');
      throw Exception('Invalid YouTube URL format');

    } catch (e) {
      print('❌ Error resolving YouTube URL: $e');
      rethrow;
    }
  }

  /// Extract live stream URL from YouTube live page
  static Future<String> _extractYouTubeLiveStreamUrl(String liveUrl) async {
    try {
      print('📥 Fetching YouTube live page: $liveUrl');

      final response = await http.get(
        Uri.parse(liveUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch YouTube page: ${response.statusCode}');
      }

      final html = response.body;

      // Try to extract video ID from the page
      // Look for patterns like "videoId":"VIDEO_ID"
      final videoIdMatch = RegExp(r'"videoId":"([^"]+)"').firstMatch(html);
      if (videoIdMatch != null) {
        final videoId = videoIdMatch.group(1);
        print('🆔 Extracted video ID from live page: $videoId');

        // Same limitation as above - need proper YouTube extraction
        throw Exception(
          'YouTube live streams not yet supported. '
          'Please try playing this station in your browser or YouTube app.'
        );
      }

      throw Exception('Could not extract video ID from YouTube live page');

    } catch (e) {
      print('❌ Error extracting YouTube live stream: $e');
      rethrow;
    }
  }
}
