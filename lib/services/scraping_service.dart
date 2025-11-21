import 'dart:convert';
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

  /// Get cities for a specific country by fetching the selector page
  static Future<List<City>> getCitiesForCountry(String countryCode) async {
    if (_cachedCities.containsKey(countryCode)) {
      return _cachedCities[countryCode]!;
    }

    try {
      // Check if this country has a two-level hierarchy (US, Canada)
      if (_isTwoLevelCountry(countryCode)) {
        print('🔍 Detected two-level country: $countryCode');
        return await _getCitiesForTwoLevelCountry(countryCode);
      }

      // Determine if this is a European country that uses radiomap.eu
      final isEuropeanCountry = _isEuropeanCountry(countryCode);
      final selectorUrl = isEuropeanCountry
          ? '$europeBaseUrl/en_$countryCode.htm'
          : '$selectorBaseUrl/en_$countryCode.htm';

      print('📥 Fetching cities from: $selectorUrl');
      final response = await http.get(
        Uri.parse(selectorUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        List<City> cities = [];

        // Parse the city list from the selector page
        cities = _parseCitiesFromSelectorPage(document, countryCode);

        _cachedCities[countryCode] = cities;
        return cities;
      } else {
        print('❌ HTTP ${response.statusCode} for $selectorUrl');
      }
    } catch (e) {
      print('❌ Error scraping cities for $countryCode: $e');
    }

    return [];
  }

  /// Get cities for two-level countries (US, Canada) that have states/provinces
  static Future<List<City>> _getCitiesForTwoLevelCountry(String countryCode) async {
    List<City> allCities = [];

    try {
      // Step 1: Fetch the country-level selector page to get states/provinces
      final selectorUrl = '$selectorBaseUrl/en_$countryCode.htm';
      print('📥 Fetching states/provinces from: $selectorUrl');

      final response = await http.get(
        Uri.parse(selectorUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode != 200) {
        print('❌ HTTP ${response.statusCode} for $selectorUrl');
        return [];
      }

      final document = html_parser.parse(utf8.decode(response.bodyBytes));

      // Step 2: Parse state/province codes from the selector dropdown
      final stateSelect = document.querySelector('select[name="jumper2"]');
      if (stateSelect == null) {
        print('❌ Could not find state/province selector (jumper2)');
        return [];
      }

      final stateOptions = stateSelect.querySelectorAll('option');
      print('✅ Found ${stateOptions.length} state/province options');

      // Step 3: For each state/province, fetch its cities
      for (var stateOption in stateOptions) {
        final value = stateOption.attributes['value'];
        final stateName = stateOption.text.trim();

        if (value == null || value.isEmpty || stateName.isEmpty ||
            stateName.contains('Select') || stateName.contains('Choose')) {
          continue;
        }

        // Extract state code from value like "en_us-ny.htm" → "ny"
        String? stateCode;
        if (value.contains('en_${countryCode}-')) {
          final parts = value.split('en_${countryCode}-');
          if (parts.length > 1) {
            stateCode = parts[1].replaceAll('.htm', '');
          }
        }

        if (stateCode == null || stateCode.isEmpty) {
          print('⚠️ Could not extract state code from: $value');
          continue;
        }

        print('📍 Processing state: $stateName ($stateCode)');

        // Step 4: Fetch cities for this state
        final stateSelectorUrl = '$selectorBaseUrl/en_${countryCode}-$stateCode.htm';
        print('  📥 Fetching cities from: $stateSelectorUrl');

        try {
          final stateResponse = await http.get(
            Uri.parse(stateSelectorUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
              'Accept-Charset': 'utf-8',
            },
          );

          if (stateResponse.statusCode == 200) {
            final stateDocument = html_parser.parse(utf8.decode(stateResponse.bodyBytes));

            // Parse cities from this state's selector page
            final citySelect = stateDocument.querySelector('select[name="jumper3"]');
            if (citySelect != null) {
              final cityOptions = citySelect.querySelectorAll('option');
              print('  ✅ Found ${cityOptions.length} cities in $stateName');

              for (var cityOption in cityOptions) {
                final cityValue = cityOption.attributes['value'];
                final cityName = cityOption.text.trim();

                if (cityValue == null || cityValue.isEmpty || cityName.isEmpty ||
                    cityName.contains('Select') || cityName.contains('Choose')) {
                  continue;
                }

                // Extract city URL from value like "../us-ny/new-york.htm"
                String? cityUrl;
                if (cityValue.startsWith('../')) {
                  cityUrl = '$baseUrl/${cityValue.replaceAll('../', '')}';
                } else if (cityValue.contains('/')) {
                  cityUrl = '$baseUrl/$cityValue';
                }

                if (cityUrl != null && cityUrl.isNotEmpty) {
                  // Include state name in city name for clarity
                  final fullCityName = '$cityName, $stateName';
                  print('  📍 Found city: $fullCityName → $cityUrl');

                  allCities.add(City(
                    name: fullCityName,
                    url: cityUrl,
                  ));
                }
              }
            } else {
              print('  ⚠️ No city selector found for $stateName');
            }
          } else {
            print('  ❌ HTTP ${stateResponse.statusCode} for $stateSelectorUrl');
          }
        } catch (e) {
          print('  ❌ Error fetching cities for $stateName: $e');
        }

        // Add a small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Total cities found for $countryCode: ${allCities.length}');
      _cachedCities[countryCode] = allCities;
      return allCities;

    } catch (e) {
      print('❌ Error in _getCitiesForTwoLevelCountry for $countryCode: $e');
      return [];
    }
  }

  /// Parse cities from the selector page content
  static List<City> _parseCitiesFromSelectorPage(Document document, String countryCode) {
    List<City> cities = [];

    // STRATEGY 1: Try to parse cities from selector dropdown (most reliable)
    final citySelect = document.querySelector('select[name="jumper2"]');
    if (citySelect != null) {
      print('✅ Found city selector dropdown (jumper2)');
      final cityOptions = citySelect.querySelectorAll('option');

      for (var cityOption in cityOptions) {
        final value = cityOption.attributes['value'];
        final cityName = cityOption.text.trim();

        if (value == null || value.isEmpty || cityName.isEmpty ||
            cityName.contains('Select') || cityName.contains('Choose')) {
          continue;
        }

        // Extract city URL from value like "../au/sydney.htm" or "../br/sao-paulo.htm"
        String? cityUrl;
        if (value.startsWith('../')) {
          cityUrl = '$baseUrl/${value.replaceAll('../', '')}';
        } else if (value.contains('/')) {
          cityUrl = '$baseUrl/$value';
        } else if (value.endsWith('.htm')) {
          // Sometimes it's just "sydney.htm" without the path
          final isEuropeanCountry = _isEuropeanCountry(countryCode);
          final baseHost = isEuropeanCountry ? 'radiomap.eu' : 'worldradiomap.com';
          cityUrl = 'https://$baseHost/$countryCode/${value}';
        }

        if (cityUrl != null && cityUrl.isNotEmpty) {
          print('  📍 Found city from selector: $cityName → $cityUrl');
          cities.add(City(
            name: cityName,
            url: cityUrl,
          ));
        }
      }

      if (cities.isNotEmpty) {
        print('✅ Parsed ${cities.length} cities from selector dropdown');
        return cities;
      }
    }

    // STRATEGY 2: Fallback to old text-based parsing
    print('⚠️ No city selector found, falling back to text parsing');

    // Get the text content and look for city names
    final bodyText = document.body?.text ?? '';

    // Split by lines and filter out empty lines and headers
    final lines = bodyText.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty &&
                        !line.contains('Select a city') &&
                        !line.contains('flag') &&
                        line.length > 2)
        .toList();

    // For each line that looks like a city name, create a City object
    for (String line in lines) {
      // Clean up the line to extract just the city name
      String cityName = line.trim();

      // Skip obvious non-city entries
      if (cityName.length < 3 ||
          cityName.contains('http') ||
          cityName.contains('www') ||
          cityName.contains('flag')) {
        continue;
      }

      // Create a URL for the city page
      final cityUrl = _buildCityUrl(countryCode, cityName);

      if (cityUrl.isNotEmpty) {
        cities.add(City(
          name: cityName,
          url: cityUrl,
        ));
      }
    }

    print('✅ Parsed ${cities.length} cities from text content');
    return cities;
  }

  /// Build the URL for a city's radio station page
  static String _buildCityUrl(String countryCode, String cityName) {
    // Remove special characters completely for URL building
    String urlCityName = cityName.toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll('\'', '')
        .replaceAll('.', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        // Remove all accented characters
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('è', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('č', 'c')
        .replaceAll('ř', 'r')
        .replaceAll('ů', 'u')
        .replaceAll('ě', 'e')
        .replaceAll('ď', 'd')
        .replaceAll('ť', 't')
        .replaceAll('ň', 'n')
        .replaceAll('ý', 'y');
    
    // Determine the base URL based on country
    final isEuropeanCountry = _isEuropeanCountry(countryCode);
    final baseHost = isEuropeanCountry ? 'radiomap.eu' : 'worldradiomap.com';
    
    final finalUrl = 'https://$baseHost/$countryCode/$urlCityName.htm';
    print('Built city URL: $finalUrl for city: $cityName');
    return finalUrl;
  }

  /// Check if a country is European (uses radiomap.eu)
  static bool _isEuropeanCountry(String countryCode) {
    const europeanCountries = {
      'ad', 'al', 'am', 'at', 'ax', 'az', 'ba', 'be', 'bg', 'by', 'ch', 'cy',
      'cz', 'de', 'dk', 'ee', 'es', 'fi', 'fo', 'fr', 'gb', 'ge', 'gi', 'gr',
      'hr', 'hu', 'ie', 'im', 'is', 'it', 'je', 'gg', 'ks', 'li', 'lt', 'lu',
      'lv', 'mc', 'md', 'me', 'mk', 'mt', 'nl', 'no', 'pl', 'pt', 'ro', 'rs',
      'ru', 'se', 'si', 'sk', 'sm', 'tr', 'ua', 'uk', 'va', 'kk', 'ab', 'os', 'pmr'
    };
    return europeanCountries.contains(countryCode);
  }

  /// Check if a country has a two-level hierarchy (country → states/provinces → cities)
  static bool _isTwoLevelCountry(String countryCode) {
    const twoLevelCountries = {'us', 'ca'};
    return twoLevelCountries.contains(countryCode);
  }

  /// Scrape radio stations from a city page
  static Future<List<RadioStation>> getStationsForCity(City city, String countryName) async {
    // Extract country code from city URL
    // For two-level countries: https://worldradiomap.com/us-ny/new-york.htm → "us"
    // For single-level countries: https://worldradiomap.com/au/sydney.htm → "au"
    String countryCode = '';
    final urlParts = city.url.split('/');
    for (var part in urlParts) {
      if (part.contains('-')) {
        // Two-level country: "us-ny" → extract "us"
        countryCode = part.split('-').first;
        if (countryCode.length == 2) break;
      } else if (part.length == 2 && !part.contains('.')) {
        // Single-level country: "au"
        countryCode = part;
        break;
      }
    }

    if (countryCode.isEmpty) {
      print('❌ Could not extract country code from URL: ${city.url}');
      return [];
    }

    try {
      print('Fetching stations from: ${city.url}');
      final response = await http.get(
        Uri.parse(city.url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(utf8.decode(response.bodyBytes));
        List<RadioStation> stations = [];
        
        // Look for station tables - radio stations are typically in table rows
        final stationRows = document.querySelectorAll('table tr');
        print('Found ${stationRows.length} table rows');
        
        for (var row in stationRows) {
          try {
            final cells = row.querySelectorAll('td');
            
            // Skip header rows or rows without enough cells
            if (cells.length < 2) continue;
            
            // First cell usually contains frequency
            final frequencyText = cells[0].text.trim();
            
            // Second cell usually contains station name and other info
            final stationCell = cells[1];
            final stationText = stationCell.text.trim();
            
            // Skip if no meaningful content
            if (frequencyText.isEmpty || stationText.isEmpty) continue;
            if (stationText.contains('MHz') || stationText.contains('kHz')) continue; // Skip headers
            
            // Skip non-radio entries (social media, page links, etc.)
            if (stationText.toLowerCase().contains('tweetar') ||
                stationText.toLowerCase().contains('facebook') ||
                stationText.toLowerCase().contains('twitter') ||
                stationText.toLowerCase().contains('estações de rádio') ||
                stationText.toLowerCase().contains('radio stations') ||
                stationText.toLowerCase().contains('stations de radio') ||
                stationText.toLowerCase().contains('emisoras de radio') ||
                stationText.toLowerCase().contains('radiostations') ||
                stationText.toLowerCase().contains('www.') ||
                stationText.toLowerCase().contains('http') ||
                frequencyText.toLowerCase().contains('follow') ||
                frequencyText.toLowerCase().contains('tweet') ||
                stationText.trim().toLowerCase() == 'rádio' ||
                stationText.trim().toLowerCase() == 'radio' ||
                stationText.trim().length < 3 ||
                frequencyText.trim().length < 2) {
              continue;
            }
            
            // Extract station name first (clean up text)
            String stationName = stationText
                .split('\n')[0] // Take first line
                .trim()
                .replaceAll(RegExp(r'^\d+\.\d+\s*'), '') // Remove frequency prefix
                .replaceAll(RegExp(r'[()]+'), '') // Remove parentheses
                .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
                .trim();
            
            // Remove common suffixes that aren't part of the station name
            if (stationName.toLowerCase().endsWith(' fm')) {
              stationName = stationName.substring(0, stationName.length - 3).trim();
            }
            if (stationName.toLowerCase().endsWith(' am')) {
              stationName = stationName.substring(0, stationName.length - 3).trim();
            }
            
            // Look for "play" links that lead to streaming pages
            final playLinks = stationCell.querySelectorAll('a[href*="/play/"]');
            String? playPageUrl;
            
            for (var link in playLinks) {
              final href = link.attributes['href'];
              if (href != null && href.contains('/play/')) {
                // Build absolute URL for the play page
                if (href.startsWith('http')) {
                  playPageUrl = href;
                } else if (href.startsWith('../')) {
                  final isEuropeanCountry = _isEuropeanCountry(countryCode);
                  final baseHost = isEuropeanCountry ? 'radiomap.eu' : 'worldradiomap.com';
                  playPageUrl = 'https://$baseHost/${href.replaceAll('../', '')}';
                } else {
                  final isEuropeanCountry = _isEuropeanCountry(countryCode);
                  final baseHost = isEuropeanCountry ? 'radiomap.eu' : 'worldradiomap.com';
                  playPageUrl = 'https://$baseHost/$countryCode/$href';
                }
                
                print('Found play page: $playPageUrl for station: $stationName');
                break; // Take the first play link found
              }
            }
            
            // Use play page URL as the streaming URL for now (will be resolved lazily when playing)
            String? streamUrl = playPageUrl;
            
            // If no play page found, try looking for direct streaming links as fallback
            if (streamUrl == null) {
              final directLinks = stationCell.querySelectorAll('a[href*="http"]');
              for (var link in directLinks) {
                final href = link.attributes['href'];
                if (href != null && (href.contains('.m3u') || href.contains('.pls') || 
                    href.contains('stream') || href.contains('.mp3') || href.contains('.aac'))) {
                  streamUrl = href;
                  print('Found direct streaming URL: $href for station: $stationName');
                  break;
                }
              }
            }
            
            // Look for station logo
            final logoImg = stationCell.querySelector('img');
            String? logoUrl;
            if (logoImg != null) {
              final imgSrc = logoImg.attributes['src'];
              if (imgSrc != null && !imgSrc.contains('icon.gif') && !imgSrc.contains('flag')) {
                // Build absolute URL for logo
                if (imgSrc.startsWith('http')) {
                  logoUrl = imgSrc;
                } else if (imgSrc.startsWith('../')) {
                  final isEuropeanCountry = _isEuropeanCountry(countryCode);
                  final baseHost = isEuropeanCountry ? 'radiomap.eu' : 'worldradiomap.com';
                  logoUrl = 'https://$baseHost/${imgSrc.replaceAll('../', '')}';
                }
              }
            }
            
            if (stationName.isNotEmpty && frequencyText.isNotEmpty) {
              print('Found station: $stationName ($frequencyText)');
              stations.add(RadioStation(
                name: stationName,
                url: streamUrl ?? '',
                city: city.name,
                country: countryName,
                frequency: frequencyText,
                logoUrl: logoUrl,
              ));
            }
          } catch (e) {
            // Skip invalid station entries
            continue;
          }
        }
        
        print('Extracted ${stations.length} stations from ${city.name}');
        return stations;
      } else {
        print('HTTP ${response.statusCode} for ${city.url}');
      }
    } catch (e) {
      print('Error scraping stations for ${city.name}: $e');
    }
    
    return [];
  }

  /// Get streaming URL from a play page using simple DOM selectors
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
        
        print('📄 Parsing HTML for streaming URLs...');
        
        // STRATEGY 1: Look for direct streaming file links (highest priority)
        final streamingSelectors = [
          'a[href*=".m3u8"]',
          'a[href*=".m3u"]',
          'a[href*=".pls"]',
          'a[href*=".aac"]',
          'a[href*=".mp3"]',
        ];
        
        for (var selector in streamingSelectors) {
          final streamingLinks = document.querySelectorAll(selector);
          for (var link in streamingLinks) {
            final href = link.attributes['href'];
            if (href != null && _isValidStreamingUrl(href)) {
              print('✅ FOUND STREAMING FILE: $href');
              return _makeAbsoluteUrl(href, playPageUrl);
            }
          }
        }
        
        // STRATEGY 2: Look for streaming domain links
        final streamingDomainSelectors = [
          'a[href*="stream"]',
          'a[href*="live"]',
          'a[href*="radio"]',
          'a[href*="azioncdn.net"]',
          'a[href*="rbsdirect.com.br"]',
          'a[href*="antena1.com.br"]',
          'a[href*="streamguys"]',
          'a[href*="icecast"]',
          'a[href*="shoutcast"]',
        ];
        
        for (var selector in streamingDomainSelectors) {
          final streamingLinks = document.querySelectorAll(selector);
          for (var link in streamingLinks) {
            final href = link.attributes['href'];
            if (href != null && _isValidStreamingUrl(href)) {
              print('✅ FOUND STREAMING DOMAIN: $href');
              return _makeAbsoluteUrl(href, playPageUrl);
            }
          }
        }
        
        // STRATEGY 3: Look for "Listen with your player" text links
        final allLinks = document.querySelectorAll('a[href]');
        for (var link in allLinks) {
          final href = link.attributes['href'];
          final linkText = link.text.toLowerCase().trim();
          
          // Check for "Listen with your player" variations
          if (linkText.contains('listen with your player') || 
              linkText.contains('ouça com o seu reprodutor') ||
              linkText.contains('écoutez avec votre lecteur') ||
              linkText.contains('ouça com seu player') ||
              linkText.contains('escutar com') ||
              linkText.contains('listen with')) {
            
            if (href != null && _isValidStreamingUrl(href)) {
              print('✅ FOUND "LISTEN WITH PLAYER" LINK: $href');
              return _makeAbsoluteUrl(href, playPageUrl);
            }
          }
        }
        
        // STRATEGY 4: Check for audio elements with src attributes
        final audioElements = document.querySelectorAll('audio[src]');
        for (var audio in audioElements) {
          final src = audio.attributes['src'];
          if (src != null && _isValidStreamingUrl(src)) {
            print('✅ FOUND AUDIO ELEMENT SRC: $src');
            return _makeAbsoluteUrl(src, playPageUrl);
          }
        }
        
        // STRATEGY 5: Look for audio source elements
        final sourceElements = document.querySelectorAll('audio source[src]');
        for (var source in sourceElements) {
          final src = source.attributes['src'];
          if (src != null && _isValidStreamingUrl(src)) {
            print('✅ FOUND AUDIO SOURCE: $src');
            return _makeAbsoluteUrl(src, playPageUrl);
          }
        }
        
        print('❌ No streaming URL found in play page: $playPageUrl');
        print('📝 Found ${allLinks.length} links total');
        
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

  /// Validate multiple stations concurrently with batch processing
  static Future<List<RadioStation>> validateStations(List<RadioStation> stations) async {
    final List<RadioStation> validatedStations = [];
    const int batchSize = 10; // Process 10 stations at a time
    
    for (int i = 0; i < stations.length; i += batchSize) {
      final batch = stations.skip(i).take(batchSize).toList();
      
      final List<Future<RadioStation>> validationFutures = batch.map((station) async {
        final validation = await validateStation(station);
        return RadioStation(
          name: station.name,
          url: station.url,
          city: station.city,
          country: station.country,
          frequency: station.frequency,
          logoUrl: station.logoUrl,
          isValid: validation['isValid'] ?? false,
          isOnline: validation['isOnline'] ?? false,
        );
      }).toList();
      
      final batchResults = await Future.wait(validationFutures);
      validatedStations.addAll(batchResults);
      
      // Add a small delay between batches to avoid overwhelming servers
      if (i + batchSize < stations.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return validatedStations;
  }

  /// Validate streaming URL and check if station is online
  /// NOTE: This validation is now LENIENT - stations with URLs are marked as valid
  /// regardless of online status, allowing users to try playing them.
  static Future<Map<String, bool>> validateStation(RadioStation station) async {
    bool isValid = false;
    bool isOnline = false;

    try {
      // LENIENT VALIDATION: If station has any URL, mark it as valid
      // This allows users to try playing stations even if connectivity check fails
      if (station.url.isEmpty) {
        return {'isValid': false, 'isOnline': false};
      }

      // Mark as valid if URL exists and looks like a streaming URL
      if (station.url.contains('/play/') ||
          station.url.contains('.m3u') || station.url.contains('.pls') ||
          station.url.contains('.aac') || station.url.contains('.mp3') ||
          station.url.contains('.ogg') || station.url.contains('.flac') ||
          station.url.contains('stream') || station.url.contains('radio') ||
          station.url.contains('live') || station.url.startsWith('http')) {
        // Mark as VALID immediately - we have a URL that could work
        isValid = true;

        // Now check if it's ONLINE (but don't fail validation if this check fails)
        try {
          final streamUrl = station.url.contains('/play/')
              ? await getStreamUrlFromPlayPage(station.url)
              : station.url;

          if (streamUrl != null && streamUrl.isNotEmpty) {
            // Try to connect to the stream with a longer timeout (5 seconds instead of 3)
            try {
              final response = await http.head(
                Uri.parse(streamUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
                  'Accept': 'audio/mpeg, audio/*, */*',
                },
              ).timeout(const Duration(seconds: 5));

              // Accept 200 OK or 206 Partial Content (common for streaming)
              isOnline = response.statusCode == 200 || response.statusCode == 206;
            } catch (headError) {
              // HEAD failed, try GET with minimal data
              try {
                final getResponse = await http.get(
                  Uri.parse(streamUrl),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0',
                    'Accept': 'audio/mpeg, audio/*, */*',
                    'Range': 'bytes=0-1023', // Only fetch first 1KB
                  },
                ).timeout(const Duration(seconds: 5));

                isOnline = getResponse.statusCode == 200 || getResponse.statusCode == 206;
              } catch (getError) {
                // Both HEAD and GET failed - mark as offline but STILL valid
                print('⚠️ Station ${station.name} connectivity check failed, but marking as valid anyway');
                isOnline = false;
              }
            }
          }
        } catch (e) {
          // Connectivity check failed, but station is STILL valid
          print('⚠️ Station ${station.name} online check failed: $e');
          print('⚠️ Marking as valid anyway - user can try to play it');
          isOnline = false; // Mark as offline but keep isValid = true
        }
      }
    } catch (e) {
      print('⚠️ Error validating station ${station.name}: $e');
      // If there's any error, but we have a URL, still mark as valid
      if (station.url.isNotEmpty && station.url.startsWith('http')) {
        isValid = true;
        isOnline = false;
      } else {
        isValid = false;
        isOnline = false;
      }
    }

    return {'isValid': isValid, 'isOnline': isOnline};
  }

  /// Clear cache
  static void clearCache() {
    _cachedCountries = null;
    _cachedCities.clear();
  }
}