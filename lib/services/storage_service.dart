import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

class StorageService {
  static const String _keySelectedCountry = 'selected_country';
  static const String _keySelectedCity = 'selected_city';
  static const String _keyFavoriteStations = 'favorite_stations';
  static const String _keyLastPlayedStations = 'last_played_stations';
  static const String _keyIsFirstLaunch = 'is_first_launch';
  static const String _keyIsDarkMode = 'is_dark_mode';
  static const String _keyCountriesCache = 'countries_cache';
  static const String _keyCitiesCache = 'cities_cache';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // First launch detection
  static Future<bool> isFirstLaunch() async {
    await init();
    return _prefs!.getBool(_keyIsFirstLaunch) ?? true;
  }

  static Future<void> setFirstLaunchComplete() async {
    await init();
    await _prefs!.setBool(_keyIsFirstLaunch, false);
  }

  // Country/City selection
  static Future<void> saveSelectedCountry(Country country) async {
    await init();
    await _prefs!.setString(_keySelectedCountry, jsonEncode(country.toJson()));
  }

  static Future<Country?> getSelectedCountry() async {
    await init();
    final countryJson = _prefs!.getString(_keySelectedCountry);
    if (countryJson != null) {
      return Country.fromJson(jsonDecode(countryJson));
    }
    return null;
  }

  static Future<void> saveSelectedCity(City city) async {
    await init();
    await _prefs!.setString(_keySelectedCity, jsonEncode(city.toJson()));
  }

  static Future<City?> getSelectedCity() async {
    await init();
    final cityJson = _prefs!.getString(_keySelectedCity);
    if (cityJson != null) {
      return City.fromJson(jsonDecode(cityJson));
    }
    return null;
  }

  // Favorite stations
  static Future<void> addFavoriteStation(RadioStation station) async {
    await init();
    final favorites = await getFavoriteStations();
    
    // Check if already exists
    final existingIndex = favorites.indexWhere((s) => s.url == station.url);
    if (existingIndex == -1) {
      favorites.add(station);
      await _saveFavoriteStations(favorites);
    }
  }

  static Future<void> removeFavoriteStation(RadioStation station) async {
    await init();
    final favorites = await getFavoriteStations();
    favorites.removeWhere((s) => s.url == station.url);
    await _saveFavoriteStations(favorites);
  }

  static Future<List<RadioStation>> getFavoriteStations() async {
    await init();
    final favoritesJson = _prefs!.getString(_keyFavoriteStations);
    if (favoritesJson != null) {
      final List<dynamic> favoritesList = jsonDecode(favoritesJson);
      return favoritesList.map((json) => RadioStation.fromJson(json)).toList();
    }
    return [];
  }

  static Future<bool> isFavoriteStation(RadioStation station) async {
    final favorites = await getFavoriteStations();
    return favorites.any((s) => s.url == station.url);
  }

  static Future<void> _saveFavoriteStations(List<RadioStation> stations) async {
    await init();
    final stationsJson = jsonEncode(stations.map((s) => s.toJson()).toList());
    await _prefs!.setString(_keyFavoriteStations, stationsJson);
  }

  // Last played stations
  static Future<void> addLastPlayedStation(RadioStation station) async {
    await init();
    final lastPlayed = await getLastPlayedStations();
    
    // Remove if already exists to avoid duplicates
    lastPlayed.removeWhere((s) => s.url == station.url);
    
    // Add to beginning
    lastPlayed.insert(0, station);
    
    // Keep only last 20
    if (lastPlayed.length > 20) {
      lastPlayed.removeRange(20, lastPlayed.length);
    }
    
    await _saveLastPlayedStations(lastPlayed);
  }

  static Future<List<RadioStation>> getLastPlayedStations() async {
    await init();
    final lastPlayedJson = _prefs!.getString(_keyLastPlayedStations);
    if (lastPlayedJson != null) {
      final List<dynamic> lastPlayedList = jsonDecode(lastPlayedJson);
      return lastPlayedList.map((json) => RadioStation.fromJson(json)).toList();
    }
    return [];
  }

  static Future<void> _saveLastPlayedStations(List<RadioStation> stations) async {
    await init();
    final stationsJson = jsonEncode(stations.map((s) => s.toJson()).toList());
    await _prefs!.setString(_keyLastPlayedStations, stationsJson);
  }

  // Theme settings
  static Future<void> setDarkMode(bool isDark) async {
    await init();
    await _prefs!.setBool(_keyIsDarkMode, isDark);
  }

  static Future<bool> isDarkMode() async {
    await init();
    return _prefs!.getBool(_keyIsDarkMode) ?? true; // Default to dark
  }

  // Cache management
  static Future<void> saveCountriesCache(List<Country> countries) async {
    await init();
    final countriesJson = jsonEncode(countries.map((c) => c.toJson()).toList());
    await _prefs!.setString(_keyCountriesCache, countriesJson);
  }

  static Future<List<Country>?> getCountriesCache() async {
    await init();
    final countriesJson = _prefs!.getString(_keyCountriesCache);
    if (countriesJson != null) {
      final List<dynamic> countriesList = jsonDecode(countriesJson);
      return countriesList.map((json) => Country.fromJson(json)).toList();
    }
    return null;
  }

  static Future<void> saveCitiesCache(String countryCode, List<City> cities) async {
    await init();
    final citiesJson = jsonEncode(cities.map((c) => c.toJson()).toList());
    await _prefs!.setString('${_keyCitiesCache}_$countryCode', citiesJson);
  }

  static Future<List<City>?> getCitiesCache(String countryCode) async {
    await init();
    final citiesJson = _prefs!.getString('${_keyCitiesCache}_$countryCode');
    if (citiesJson != null) {
      final List<dynamic> citiesList = jsonDecode(citiesJson);
      return citiesList.map((json) => City.fromJson(json)).toList();
    }
    return null;
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await init();
    await _prefs!.clear();
  }
}