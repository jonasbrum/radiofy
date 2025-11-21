import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_station.dart';
import '../services/scraping_service.dart';
import '../services/storage_service.dart';
import '../providers/app_state.dart';
import 'main_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<Country> _countries = [];
  List<City> _cities = [];
  Country? _selectedCountry;
  City? _selectedCity;
  bool _isLoadingCountries = true;
  bool _isLoadingCities = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });

    try {
      // Always scrape fresh data for testing
      // final cachedCountries = await StorageService.getCountriesCache();
      // if (cachedCountries != null && cachedCountries.isNotEmpty) {
      //   setState(() {
      //     _countries = cachedCountries;
      //     _isLoadingCountries = false;
      //   });
      //   return;
      // }

      // Scrape from website
      print('Scraping countries from website...');
      final countries = await ScrapingService.getCountries();
      print('Found ${countries.length} countries');
      await StorageService.saveCountriesCache(countries);
      
      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      print('Error loading countries: $e');
      setState(() {
        _isLoadingCountries = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading countries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCitiesForCountry(Country country) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = null;
    });

    try {
      // Always scrape fresh data for testing
      // final cachedCities = await StorageService.getCitiesCache(country.code);
      // if (cachedCities != null && cachedCities.isNotEmpty) {
      //   setState(() {
      //     _cities = cachedCities;
      //     _isLoadingCities = false;
      //   });
      //   return;
      // }

      // Scrape from website
      print('Scraping cities for ${country.name} (${country.code})...');
      final cities = await ScrapingService.getCitiesForCountry(country.code);
      print('Found ${cities.length} cities');
      await StorageService.saveCitiesCache(country.code, cities);
      
      setState(() {
        _cities = cities;
        _isLoadingCities = false;
      });
    } catch (e) {
      print('Error loading cities: $e');
      setState(() {
        _isLoadingCities = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeSetup() async {
    if (_selectedCountry == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both country and city'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      // Save selections
      await StorageService.saveSelectedCountry(_selectedCountry!);
      await StorageService.saveSelectedCity(_selectedCity!);
      await StorageService.setFirstLaunchComplete();

      // Update app state
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setSelectedCountry(_selectedCountry!);
        appState.setSelectedCity(_selectedCity!);

        // Navigate to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCompleting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a1a),
              Color(0xFF0d0d0d),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                      image: AssetImage('assets/radiofylogo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Welcome text
                const Text(
                  'Welcome to Radiofy',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your location to discover local radio stations',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Country dropdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3a3a3a)),
                  ),
                  child: _isLoadingCountries
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B35),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading countries...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : DropdownButton<Country>(
                          isExpanded: true,
                          value: _selectedCountry,
                          hint: const Text(
                            '- Select a country -',
                            style: TextStyle(color: Colors.grey),
                          ),
                          dropdownColor: const Color(0xFF2a2a2a),
                          style: const TextStyle(color: Colors.white),
                          underline: Container(),
                          items: _countries.map((country) {
                            return DropdownMenuItem<Country>(
                              value: country,
                              child: Text(country.name),
                            );
                          }).toList(),
                          onChanged: (Country? country) {
                            setState(() {
                              _selectedCountry = country;
                            });
                            if (country != null) {
                              _loadCitiesForCountry(country);
                            }
                          },
                        ),
                ),
                const SizedBox(height: 16),

                // City dropdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _selectedCountry == null 
                        ? const Color(0xFF1a1a1a) 
                        : const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedCountry == null 
                          ? const Color(0xFF2a2a2a) 
                          : const Color(0xFF3a3a3a),
                    ),
                  ),
                  child: _selectedCountry == null
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            '- Select a city -',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : _isLoadingCities
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF6B35),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Loading cities...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButton<City>(
                              isExpanded: true,
                              value: _selectedCity,
                              hint: const Text(
                                '- Select a city -',
                                style: TextStyle(color: Colors.grey),
                              ),
                              dropdownColor: const Color(0xFF2a2a2a),
                              style: const TextStyle(color: Colors.white),
                              underline: Container(),
                              items: _cities.map((city) {
                                return DropdownMenuItem<City>(
                                  value: city,
                                  child: Text(city.name),
                                );
                              }).toList(),
                              onChanged: (City? city) {
                                setState(() {
                                  _selectedCity = city;
                                });
                              },
                            ),
                ),
                const SizedBox(height: 48),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedCountry != null && 
                               _selectedCity != null && 
                               !_isCompleting
                        ? _completeSetup
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      disabledBackgroundColor: const Color(0xFF3a3a3a),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCompleting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Setting up...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}