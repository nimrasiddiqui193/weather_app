import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchService {
  static const String _storageKey = 'weatherly_recent_cities';
  static const int _maxRecentCities = 8;

  Future<List<String>> getRecentCities() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_storageKey) ?? [];
  }

  Future<void> saveCity(String city) async {
    final cleanedCity = city.trim();
    if (cleanedCity.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    final recentCities = preferences.getStringList(_storageKey) ?? [];

    recentCities.removeWhere(
      (existingCity) => existingCity.toLowerCase() == cleanedCity.toLowerCase(),
    );

    recentCities.insert(0, cleanedCity);

    await preferences.setStringList(
      _storageKey,
      recentCities.take(_maxRecentCities).toList(),
    );
  }

  Future<void> removeCity(String city) async {
    final preferences = await SharedPreferences.getInstance();
    final recentCities = preferences.getStringList(_storageKey) ?? [];

    recentCities.removeWhere(
      (existingCity) => existingCity.toLowerCase() == city.toLowerCase(),
    );

    await preferences.setStringList(_storageKey, recentCities);
  }

  Future<void> clearRecentCities() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
