class RadioStation {
  final String name;
  final String url;
  final String city;
  final String country;
  final String frequency;
  final String? logoUrl;
  final bool isValid;
  final bool isOnline;

  RadioStation({
    required this.name,
    required this.url,
    required this.city,
    required this.country,
    required this.frequency,
    this.logoUrl,
    this.isValid = true,
    this.isOnline = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'city': city,
      'country': country,
      'frequency': frequency,
      'logoUrl': logoUrl,
      'isValid': isValid,
      'isOnline': isOnline,
    };
  }

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      frequency: json['frequency'] ?? '',
      logoUrl: json['logoUrl'],
      isValid: json['isValid'] ?? true,
      isOnline: json['isOnline'] ?? true,
    );
  }
}

class Country {
  final String name;
  final String code;
  final List<City> cities;

  Country({
    required this.name,
    required this.code,
    this.cities = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'cities': cities.map((city) => city.toJson()).toList(),
    };
  }

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      cities: (json['cities'] as List<dynamic>?)
          ?.map((cityJson) => City.fromJson(cityJson))
          .toList() ?? [],
    );
  }
}

class City {
  final String name;
  final String url;
  final List<RadioStation> stations;

  City({
    required this.name,
    required this.url,
    this.stations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'stations': stations.map((station) => station.toJson()).toList(),
    };
  }

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      stations: (json['stations'] as List<dynamic>?)
          ?.map((stationJson) => RadioStation.fromJson(stationJson))
          .toList() ?? [],
    );
  }
}