import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/radio_station.dart';

class ScrapingService {
  static const String baseUrl = 'https://worldradiomap.com';
  static const String selectorBaseUrl = 'https://worldradiomap.com/selector';
  static const String europeBaseUrl = 'https://radiomap.eu/selector';
  
  // Cache for countries and cities to avoid repeated requests
  static List<Country>? _cachedCountries;
  static final Map<String, List<City>> _cachedCities = {};

  /// Scrape countries from the main page dropdown
  static Future<List<Country>> getCountries() async {
    if (_cachedCountries != null) {
      return _cachedCountries!;
    }

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        
        // Look for the country dropdown select element with name="jumper1"
        final countrySelect = document.querySelector('select[name="jumper1"]');
        
        List<Country> countries = [];
        
        if (countrySelect != null) {
          final options = countrySelect.querySelectorAll('option');
          
          for (var option in options) {
            final value = option.attributes['value'];
            final text = option.text.trim();
            
            if (value != null && value.isNotEmpty && 
                text.isNotEmpty && 
                !text.contains('Select') && 
                !text.contains('Choose')) {
              
              // Extract country code from selector URL like "selector/en_us.htm" or "https://radiomap.eu/selector/en_uk.htm"
              String countryCode = '';
              if (value.contains('en_')) {
                final parts = value.split('en_');
                if (parts.length > 1) {
                  countryCode = parts[1].replaceAll('.htm', '');
                }
              }
              
              if (countryCode.isNotEmpty) {
                countries.add(Country(
                  name: text,
                  code: countryCode,
                ));
              }
            }
          }
        }
        
        _cachedCountries = countries;
        return countries;
      }
    } catch (e) {
      // Error scraping countries: $e
    }
    
    // Fallback to hardcoded popular countries if scraping fails
    return _getFallbackCountries();
  }

  /// Get streaming URL from a play page
  static Future<String?> getStreamUrlFromPlayPage(String playPageUrl) async {
    try {
      print('🔍 Fetching streaming URL from play page: $playPageUrl');
      final response = await http.get(
        Uri.parse(playPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        final htmlContent = response.body;
        
        print('📄 HTML content length: ${htmlContent.length}');
        
        // PRIMARY STRATEGY: Look for "Listen with your player" links
        final streamLinks = document.querySelectorAll('a[href]');
        print('🔗 Found ${streamLinks.length} links to analyze');
        
        for (var link in streamLinks) {
          final href = link.attributes['href'];
          final linkText = link.text.toLowerCase().trim();
          
          if (href != null) {
            print('🔍 Analyzing link: "$linkText" -> $href');
            
            // Look for "Listen with your player" links (English/Portuguese)
            if (linkText.contains('listen with your player') || 
                linkText.contains('ouça com o seu reprodutor') ||
                linkText.contains('ouça com seu player') ||
                linkText.contains('escutar com') ||
                linkText.contains('listen with') ||
                linkText.contains('player') && linkText.contains('ouça')) {
              
              print('🎯 FOUND PLAYER LINK: $href');
              if (_isValidStreamingUrl(href)) {
                print('✅ VALID STREAMING URL: $href');
                return _makeAbsoluteUrl(href, playPageUrl);
              }
            }
            
            // Look for direct streaming URLs in any link
            if (_isValidStreamingUrl(href)) {
              print('✅ DIRECT STREAMING URL FOUND: $href');
              return _makeAbsoluteUrl(href, playPageUrl);
            }
          }
        }
        
        // SECONDARY STRATEGY: Search for HLS.js loadSource calls
        print('🔍 Searching for HLS.js loadSource calls...');
        if (htmlContent.contains('hls.loadSource')) {
          // Simple pattern to find HLS URLs
          final hlsPattern = RegExp(r'hls\.loadSource\(["\']([^"\']*)["\'\])');
          final hlsMatch = hlsPattern.firstMatch(htmlContent);
          if (hlsMatch != null) {
            final streamUrl = hlsMatch.group(1);
            if (streamUrl != null && _isValidStreamingUrl(streamUrl)) {
              print('✅ FOUND HLS.js STREAM URL: $streamUrl');
              return streamUrl;
            }
          }
        }
        
        // TERTIARY STRATEGY: Look for specific Brazilian streaming domains
        print('🔍 Searching HTML content for Brazilian streaming URLs...');
        
        final brazilianPatterns = [
          r'https://[^\\s"<>]*azioncdn\.net[^\\s"<>]*\.m3u8',
          r'https://[^\\s"<>]*rbsdirect\.com\.br[^\\s"<>]*\.m3u8',
          r'https://stream\.antena1\.com\.br[^\\s"<>]*',
          r'https://[^\\s"<>]*kshost\.com\.br[^\\s"<>]*',
          r'https://[^\\s"<>]*webnow\.com\.br[^\\s"<>]*',
        ];
        
        for (var pattern in brazilianPatterns) {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(htmlContent);
          
          for (var match in matches) {
            final url = match.group(0);
            if (url != null && _isValidStreamingUrl(url)) {
              print('✅ FOUND BRAZILIAN STREAMING URL: $url');
              return url;
            }
          }
        }
        
        // FINAL STRATEGY: Look for any streaming file extensions
        final streamingPatterns = [
          r'https://[^\\s"<>]+\.m3u8[^\\s"<>]*',
          r'https://[^\\s"<>]+\.m3u[^\\s"<>]*', 
          r'https://[^\\s"<>]+\.pls[^\\s"<>]*',
          r'https://[^\\s"<>]+\.aac[^\\s"<>]*',
          r'https://[^\\s"<>]+\.mp3[^\\s"<>]*',
        ];
        
        for (var pattern in streamingPatterns) {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(htmlContent);
          
          for (var match in matches) {
            final url = match.group(0);
            if (url != null && _isValidStreamingUrl(url)) {
              print('✅ FOUND STREAMING FILE: $url');
              return url;
            }
          }
        }
        
        print('❌ No streaming URL found in play page: $playPageUrl');
        print('📝 HTML sample (first 500 chars):');
        print(htmlContent.substring(0, math.min(500, htmlContent.length)));
        
      } else {
        print('❌ Failed to fetch play page: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching streaming URL from play page: $e');
    }
    
    return null;
  }

  /// Check if URL is a valid streaming URL
  static bool _isValidStreamingUrl(String url) {
    if (url.isEmpty || url.length < 10) return false;
    
    // Exclude obviously non-streaming URLs
    if (url.contains('icon') || url.contains('logo') || url.contains('flag')) return false;
    if (url.contains('facebook') || url.contains('twitter') || url.contains('instagram')) return false;
    if (url.contains('mailto:') || url.contains('javascript:')) return false;
    if (url.contains('.jpg') || url.contains('.png') || url.contains('.gif') || url.contains('.svg')) return false;
    if (url.contains('.html') || url.contains('.htm') || url.contains('.php')) return false;
    
    // Must start with http or https
    if (!url.startsWith('http')) return false;
    
    // HIGH CONFIDENCE: Known Brazilian streaming domains
    final highConfidenceDomains = [
      'azioncdn.net',
      'rbsdirect.com.br',
      'stream.antena1.com.br',
      'kshost.com.br',
      'webnow.com.br',
      'streamtheworld.com',
      'tunein.streamguys',
      'playerservices',
      'streamguys',
      'shoutcast',
      'icecast',
    ];
    
    for (var domain in highConfidenceDomains) {
      if (url.contains(domain)) {
        print('✅ High confidence domain match: $domain');
        return true;
      }
    }
    
    // HIGH CONFIDENCE: HLS streaming files
    if (url.contains('.m3u8') || url.contains('playlist.m3u8')) {
      print('✅ HLS playlist file detected');
      return true;
    }
    
    // MEDIUM CONFIDENCE: Other streaming file extensions
    if (url.contains('.m3u') || url.contains('.pls') || url.contains('.aac') || url.contains('.mp3') || url.contains('.ogg')) {
      print('✅ Streaming file extension detected');
      return true;
    }
    
    // LOW CONFIDENCE: Contains stream/listen/radio in path
    if ((url.contains('/stream') || url.contains('/listen') || url.contains('radio')) && 
        !url.contains('www.') && !url.contains('.html') && !url.contains('.htm')) {
      print('✅ Stream/listen/radio in path detected');
      return true;
    }
    
    return false;
  }

  /// Make URL absolute
  static String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    } else if (url.startsWith('//')) {
      return 'https:$url';
    } else if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    } else {
      final uri = Uri.parse(baseUrl);
      final basePath = uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
      return '${uri.scheme}://${uri.host}$basePath$url';
    }
  }

  /// Fallback countries if scraping fails
  static List<Country> _getFallbackCountries() {
    return [
      Country(name: 'Brazil', code: 'br'),
      Country(name: 'United States of America', code: 'us'),
      Country(name: 'United Kingdom', code: 'uk'),
      Country(name: 'Germany', code: 'de'),
      Country(name: 'France', code: 'fr'),
      Country(name: 'Italy', code: 'it'),
      Country(name: 'Spain', code: 'es'),
      Country(name: 'Canada', code: 'ca'),
      Country(name: 'Australia', code: 'au'),
      Country(name: 'Japan', code: 'jp'),
    ];
  }

  /// Clear cache
  static void clearCache() {
    _cachedCountries = null;
    _cachedCities.clear();
  }
}