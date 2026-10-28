class Weather {
  final String city;
  final double temp;
  final double feelsLike;
  final String description;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final double visibilityKm;
  final String sunrise;
  final String sunset;
  final String iconCode;

  const Weather({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibilityKm,
    required this.sunrise,
    required this.sunset,
    required this.iconCode,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final wind = json['wind'] as Map<String, dynamic>? ?? {};
    final sys = json['sys'] as Map<String, dynamic>? ?? {};
    final weatherItems = json['weather'] as List<dynamic>? ?? [];

    final condition =
        weatherItems.isNotEmpty && weatherItems.first is Map<String, dynamic>
            ? weatherItems.first as Map<String, dynamic>
            : <String, dynamic>{};

    final timezoneOffset = (json['timezone'] as num?)?.toInt() ?? 0;

    String formatCityTime(dynamic rawTimestamp) {
      final timestamp = (rawTimestamp as num?)?.toInt();

      if (timestamp == null || timestamp <= 0) {
        return '--:--';
      }

      final cityTime = DateTime.fromMillisecondsSinceEpoch(
        timestamp * 1000,
        isUtc: true,
      ).add(Duration(seconds: timezoneOffset));

      final hour24 = cityTime.hour;
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final minute = cityTime.minute.toString().padLeft(2, '0');
      final period = hour24 >= 12 ? 'PM' : 'AM';

      return '$hour12:$minute $period';
    }

    return Weather(
      city: json['name'] as String? ?? 'Unknown city',
      temp: (main['temp'] as num?)?.toDouble() ?? 0,
      feelsLike:
          (main['feels_like'] as num?)?.toDouble() ??
          (main['temp'] as num?)?.toDouble() ??
          0,
      description: condition['description'] as String? ?? '',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0,
      pressure: (main['pressure'] as num?)?.toInt() ?? 0,
      visibilityKm: ((json['visibility'] as num?)?.toDouble() ?? 0) / 1000,
      sunrise: formatCityTime(sys['sunrise']),
      sunset: formatCityTime(sys['sunset']),
      iconCode: condition['icon'] as String? ?? '02d',
    );
  }
}
