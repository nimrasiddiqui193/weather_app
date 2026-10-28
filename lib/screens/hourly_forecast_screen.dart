import 'package:flutter/material.dart';

import '../models/forecast.dart';
import '../services/weather_service.dart';

class HourlyForecastScreen extends StatefulWidget {
  final String city;
  final bool useFahrenheit;
  final ValueChanged<bool> onTemperatureUnitChanged;
  final VoidCallback onThemeToggle;

  const HourlyForecastScreen({
    super.key,
    required this.city,
    required this.useFahrenheit,
    required this.onTemperatureUnitChanged,
    required this.onThemeToggle,
  });

  @override
  State<HourlyForecastScreen> createState() => _HourlyForecastScreenState();
}

class _HourlyForecastScreenState extends State<HourlyForecastScreen> {
  final WeatherService _service = WeatherService();

  List<ForecastDay> _forecast = [];
  bool _loading = true;
  String? _error;
  late bool _useFahrenheit;

  Color get _textColor => Theme.of(context).colorScheme.onSurface;

  Color get _mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    _useFahrenheit = widget.useFahrenheit;
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _service.fetchHourlyForecast(widget.city);

      if (!mounted) return;

      setState(() {
        _forecast = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _temperature(double celsius) {
    final value = _useFahrenheit ? (celsius * 9 / 5) + 32 : celsius;

    return '${value.round()}°${_useFahrenheit ? 'F' : 'C'}';
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:00 $period';
  }

  String _dayLabel(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final today = DateTime.now();

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    }

    final tomorrow = today.add(const Duration(days: 1));

    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }

    return days[date.weekday - 1];
  }

  Widget _weatherIcon(String code) {
    return Image.network(
      'https://openweathermap.org/img/wn/${code}@2x.png',
      width: 54,
      height: 54,
      errorBuilder: (_, _, _) => const Icon(Icons.cloud_outlined, size: 32),
    );
  }

  Widget _buildForecastCard(ForecastDay item, int index) {
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index == 0 ? 'Next' : _dayLabel(item.date),
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeLabel(item.date),
                  style: TextStyle(color: _mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
          _weatherIcon(item.iconCode),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.description.isEmpty
                  ? 'Weather unavailable'
                  : '${item.description[0].toUpperCase()}'
                      '${item.description.substring(1)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _mutedColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _temperature(item.temp),
            style: TextStyle(
              color: _textColor,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          '3-Hour Forecast',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nextValue = !_useFahrenheit;

              setState(() => _useFahrenheit = nextValue);
              widget.onTemperatureUnitChanged(nextValue);
            },
            child: Text(
              _useFahrenheit ? '°F' : '°C',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: widget.onThemeToggle,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadForecast,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.city,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Weather predictions for approximately the next 24 hours',
                style: TextStyle(color: _mutedColor, fontSize: 14),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 45),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadForecast,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else if (_forecast.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Center(child: Text('No forecast data is available.')),
                )
              else
                ..._forecast.asMap().entries.map(
                  (entry) => _buildForecastCard(entry.value, entry.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
