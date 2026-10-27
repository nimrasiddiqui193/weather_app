class ForecastDay {
  final DateTime date;
  final double temp;
  final String description;

  ForecastDay({
    required this.date,
    required this.temp,
    required this.description,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.parse(json['dt_txt']),
      temp: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'],
    );
  }
}
