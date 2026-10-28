import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';
import '../models/forecast.dart';
import '../secrets.dart';

class WeatherService {
  static const String _apiKey = weatherApiKey;

  static const String _weatherUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  static const String _forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';

  static const Duration _timeout = Duration(seconds: 10);

  static final http.Client _client = http.Client();

  Exception _errorFor(int statusCode) {
    switch (statusCode) {
      case 400:
        return Exception('Invalid city name. Please try another.');
      case 401:
        return Exception('Invalid API key. Check secrets.dart.');
      case 404:
        return Exception('City not found. Check the spelling.');
      case 429:
        return Exception('Too many requests. Please wait and try again.');
      default:
        if (statusCode >= 500) {
          return Exception('Weather service is temporarily unavailable.');
        }

        return Exception('Request failed ($statusCode). Please try again.');
    }
  }

  // Current weather and additional weather details.
  Future<Weather> fetchWeather(String city) async {
    final url = Uri.parse(_weatherUrl).replace(
      queryParameters: {'q': city.trim(), 'appid': _apiKey, 'units': 'metric'},
    );

    try {
      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        return Weather.fromJson(json);
      }

      throw _errorFor(response.statusCode);
    } on TimeoutException {
      throw Exception('Weather request timed out. Please try again.');
    } on http.ClientException {
      throw Exception('Connection failed. Check your internet connection.');
    } on FormatException {
      throw Exception('Invalid response from the weather service.');
    }
  }

  // Daily entries for the existing five-day forecast.
  Future<List<ForecastDay>> fetchForecast(String city) async {
    final url = Uri.parse(_forecastUrl).replace(
      queryParameters: {'q': city.trim(), 'appid': _apiKey, 'units': 'metric'},
    );

    try {
      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        final List<dynamic> items = json['list'] as List<dynamic>;

        return items
            .where((item) => (item['dt_txt'] as String).contains('12:00:00'))
            .map((item) => ForecastDay.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw _errorFor(response.statusCode);
    } on TimeoutException {
      throw Exception('Forecast timed out. Please try again.');
    } on http.ClientException {
      throw Exception('Connection failed. Check your internet connection.');
    } on FormatException {
      throw Exception('Invalid forecast data received.');
    }
  }

  // Upcoming forecast entries at roughly three-hour intervals.
  Future<List<ForecastDay>> fetchHourlyForecast(String city) async {
    final url = Uri.parse(_forecastUrl).replace(
      queryParameters: {'q': city.trim(), 'appid': _apiKey, 'units': 'metric'},
    );

    try {
      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        final List<dynamic> items = json['list'] as List<dynamic>;
        final now = DateTime.now().toUtc();

        return items
            .where((item) {
              final forecast = item as Map<String, dynamic>;
              final timestamp = (forecast['dt'] as num).toInt();

              final forecastTime = DateTime.fromMillisecondsSinceEpoch(
                timestamp * 1000,
                isUtc: true,
              );

              return forecastTime.isAfter(now);
            })
            .take(8)
            .map((item) {
              return ForecastDay.fromJson(item as Map<String, dynamic>);
            })
            .toList();
      }

      throw _errorFor(response.statusCode);
    } on TimeoutException {
      throw Exception('Forecast timed out. Please try again.');
    } on http.ClientException {
      throw Exception('Connection failed. Check your internet connection.');
    } on FormatException {
      throw Exception('Invalid forecast data received.');
    }
  }
}
