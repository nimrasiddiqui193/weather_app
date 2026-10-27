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

  Exception _errorFor(int statusCode) {
    if (statusCode == 404) {
      return Exception('City not found');
    } else if (statusCode == 401) {
      return Exception('Invalid API key. Check your key in secrets.dart');
    } else if (statusCode == 429) {
      return Exception('Too many requests. Wait a few minutes and try again.');
    } else {
      return Exception('Server error ($statusCode). Try again.');
    }
  }

  Future<Weather> fetchWeather(String city) async {
    final url = Uri.parse(
      '$_weatherUrl?q=${Uri.encodeComponent(city)}&appid=$_apiKey&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Weather.fromJson(json);
    }
    throw _errorFor(response.statusCode);
  }

  Future<List<ForecastDay>> fetchForecast(String city) async {
    final url = Uri.parse(
      '$_forecastUrl?q=${Uri.encodeComponent(city)}&appid=$_apiKey&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List items = json['list'];

      // Keep only the 12:00 noon entry of each day
      return items
          .where((item) => (item['dt_txt'] as String).contains('12:00:00'))
          .map((item) => ForecastDay.fromJson(item))
          .toList();
    }
    throw _errorFor(response.statusCode);
  }
}
