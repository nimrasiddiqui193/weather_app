class ForecastDay {
  final DateTime date;
  final double temp;
  final String description;
  final String iconCode;

  ForecastDay({
    required this.date,
    required this.temp,
    required this.description,
    required this.iconCode,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    final weatherData = json['weather'][0] as Map<String, dynamic>;

    return ForecastDay(
      date: DateTime.parse(json['dt_txt'] as String),
      temp: (json['main']['temp'] as num).toDouble(),
      description: weatherData['description'] as String,
      iconCode: weatherData['icon'] as String,
    );
  }
}
